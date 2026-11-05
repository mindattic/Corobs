package com.mindattic.corobs.mining;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

/** Proposes rules between the patterns of two plies: for every source pattern, the target pattern holding the
 *  largest share of its members, kept when that share reaches {@link #minSupport()}. Bits = support × the source
 *  pattern's bits. Deterministic. */
public final class RuleMiner {
    private final double minSupport;

    /** Support of at least 0.8. */
    public RuleMiner() { this(0.8); }

    /** Proposes rules whose support reaches {@code minSupport}, in (0, 1]. */
    public RuleMiner(double minSupport) {
        if (minSupport <= 0 || minSupport > 1) throw new IllegalArgumentException("minSupport must lie in (0, 1]");
        this.minSupport = minSupport;
    }

    /** The smallest share of a source pattern's members that must land in the best target pattern. */
    public double minSupport() { return minSupport; }

    /** The rules from {@code sourcePly}'s patterns to {@code targetPly}'s, ordered by bits descending (stable). */
    public <TId> List<Rule<TId>> mine(String sourcePly, List<Pattern<TId>> source, String targetPly, List<Pattern<TId>> target) {
        if (sourcePly.equals(targetPly)) throw new IllegalArgumentException("A rule relates two different plies.");
        List<Rule<TId>> rules = new ArrayList<>();
        for (Pattern<TId> p : source) {
            Pattern<TId> best = null;
            int bestCount = 0;
            for (Pattern<TId> q : target) {
                int count = 0;
                for (TId m : p.members()) if (q.contains(m)) count++;
                if (count > bestCount) {
                    best = q;
                    bestCount = count;
                }
            }
            if (best == null) continue;
            double support = bestCount / (double) p.members().size();
            if (support >= minSupport) rules.add(new Rule<>(sourcePly, p, targetPly, best, support, support * p.bits()));
        }
        rules.sort(Comparator.<Rule<TId>>comparingDouble(Rule::bits).reversed());
        return List.copyOf(rules);
    }
}
