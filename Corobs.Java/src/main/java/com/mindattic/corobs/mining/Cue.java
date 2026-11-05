package com.mindattic.corobs.mining;

import com.mindattic.corobs.geometry.Correlithm;
import com.mindattic.corobs.geometry.NCube;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;

/** For every rule, every member of its source whose point on the target ply lies no closer than
 *  {@link #targetDeviations()} σ below standard distance from the target centroid is a hit. Bits = (bits of the
 *  member's distance to the source centroid) × rule support. Deterministic. */
public final class Cue {
    private final double targetDeviations;

    /** A 1σ pass/fail line. */
    public Cue() { this(1); }

    /** A cueing instrument using {@code targetDeviations} as the pass/fail line. */
    public Cue(double targetDeviations) {
        if (targetDeviations < 0) throw new IllegalArgumentException("targetDeviations must not be negative");
        this.targetDeviations = targetDeviations;
    }

    /** How close to the target centroid, in σ below standard distance, a member must land to not be a hit. */
    public double targetDeviations() { return targetDeviations; }

    /** Hits with ids tie-broken in natural order. */
    @SuppressWarnings({"unchecked", "rawtypes"})
    public <TId> List<Hit<TId>> find(List<Rule<TId>> rules, Map<String, ? extends Map<TId, Correlithm>> plies) {
        return find(rules, plies, (Comparator<? super TId>) (Comparator) Comparator.naturalOrder());
    }

    /**
     * @param rules confirmed rules
     * @param plies each ply's points by id, keyed by ply name
     * @param order tie-break order for ids at equal bits
     */
    public <TId> List<Hit<TId>> find(List<Rule<TId>> rules, Map<String, ? extends Map<TId, Correlithm>> plies, Comparator<? super TId> order) {
        List<Hit<TId>> hits = new ArrayList<>();
        for (Rule<TId> rule : rules) {
            Map<TId, Correlithm> sourcePoints = plies.get(rule.sourcePly());
            if (sourcePoints == null) throw new IllegalArgumentException("No points for ply '" + rule.sourcePly() + "'.");
            Map<TId, Correlithm> targetPoints = plies.get(rule.targetPly());
            if (targetPoints == null) throw new IllegalArgumentException("No points for ply '" + rule.targetPly() + "'.");
            int n = rule.target().centroid().dimensions();
            double farEnough = NCube.distanceAtDeviations(n, targetDeviations);
            for (TId id : rule.source().members()) {
                Correlithm tp = targetPoints.get(id), sp = sourcePoints.get(id);
                if (tp == null || sp == null) continue;
                double targetDistance = tp.distanceTo(rule.target().centroid());
                if (targetDistance < farEnough) continue;
                double sourceDistance = sp.distanceTo(rule.source().centroid());
                double bits = NCube.bitContent(sp.dimensions(), sourceDistance) * rule.support();
                hits.add(new Hit<>(id, rule, sourceDistance, targetDistance, bits, 0));
            }
        }
        hits.sort(Comparator.<Hit<TId>>comparingDouble(Hit::bits).reversed().thenComparing((x, y) -> order.compare(x.id(), y.id())));
        List<Hit<TId>> ranked = new ArrayList<>(hits.size());
        for (int i = 0; i < hits.size(); i++) ranked.add(hits.get(i).withRank(i + 1));
        return List.copyOf(ranked);
    }
}
