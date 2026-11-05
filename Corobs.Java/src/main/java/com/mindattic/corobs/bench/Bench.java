package com.mindattic.corobs.bench;

import com.mindattic.corobs.Equality;
import com.mindattic.corobs.seeding.SeededPrng;

import java.util.ArrayList;
import java.util.Collection;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Function;

/** Scores any way of relating things against any other on the same ground truth. Everything here is arithmetic
 *  over ids; the caller supplies the truth and the predictors. */
public final class Bench {
    private Bench() {}

    /** An unordered pair of ids, as listed. */
    public record Pair<TId>(TId a, TId b) {}

    /** {@link #holdoutRecall(List, double, long, Function, Equality)} with {@link Object#equals}. */
    public static <TId> RecallResult holdoutRecall(List<Pair<TId>> truePairs, double holdoutFraction, long seed,
                                                   Function<TId, ? extends Collection<TId>> neighbours) {
        return holdoutRecall(truePairs, holdoutFraction, seed, neighbours, null);
    }

    /** Hide {@code holdoutFraction} of the distinct true relationships (deterministically, by seed), ask the
     *  predictor for each hidden endpoint's neighbours, and count how many hidden pairs come back. */
    public static <TId> RecallResult holdoutRecall(List<Pair<TId>> truePairs, double holdoutFraction, long seed,
                                                   Function<TId, ? extends Collection<TId>> neighbours, Equality<? super TId> comparer) {
        if (holdoutFraction <= 0 || holdoutFraction >= 1) throw new IllegalArgumentException("holdoutFraction must lie in (0, 1)");
        Equality<? super TId> cmp = comparer != null ? comparer : Equality.natural();
        Equality<Pair<TId>> pairCmp = pairEquality(cmp);

        Set<Equality.Key<Pair<TId>>> truth = new HashSet<>();
        for (Pair<TId> p : truePairs) truth.add(new Equality.Key<>(canon(p), pairCmp));

        SeededPrng prng = new SeededPrng(seed);
        // COR-T4 (docs/BUGS.md): a pair listed twice, or both ways round, is one relationship to hide.
        LinkedHashSet<Equality.Key<Pair<TId>>> distinct = new LinkedHashSet<>();
        for (Pair<TId> p : truePairs) distinct.add(new Equality.Key<>(canon(p), pairCmp));
        List<Pair<TId>> shuffled = new ArrayList<>(distinct.size());
        for (Equality.Key<Pair<TId>> k : distinct) shuffled.add(k.value());
        for (int i = shuffled.size() - 1; i > 0; i--) {
            int j = prng.next(i + 1);
            Pair<TId> t = shuffled.get(i);
            shuffled.set(i, shuffled.get(j));
            shuffled.set(j, t);
        }
        int take = (int) Math.rint(shuffled.size() * holdoutFraction);
        List<Pair<TId>> hidden = new ArrayList<>(take);
        for (int i = 0; i < take; i++) hidden.add(canon(shuffled.get(i)));
        Set<Equality.Key<Pair<TId>>> hiddenSet = new HashSet<>();
        for (Pair<TId> p : hidden) hiddenSet.add(new Equality.Key<>(p, pairCmp));

        int recovered = 0, predicted = 0, predictedTrue = 0;
        LinkedHashSet<Equality.Key<TId>> endpoints = new LinkedHashSet<>();
        for (Pair<TId> p : hidden) {
            endpoints.add(new Equality.Key<>(p.a(), cmp));
            endpoints.add(new Equality.Key<>(p.b(), cmp));
        }
        Set<Equality.Key<Pair<TId>>> seen = new HashSet<>();
        for (Equality.Key<TId> e : endpoints)
            for (TId nb : neighbours.apply(e.value())) {
                Equality.Key<Pair<TId>> pair = new Equality.Key<>(canon(new Pair<>(e.value(), nb)), pairCmp);
                if (!seen.add(pair)) continue;
                predicted++;
                if (truth.contains(pair)) predictedTrue++;
                if (hiddenSet.remove(pair)) recovered++;
            }
        return new RecallResult(hidden.size(), recovered, predicted, predictedTrue);
    }

    /** {@link #reach(Collection, Function, int, Equality)} with {@link Object#equals}. */
    public static <TId> ReachResult reach(Collection<TId> ids, Function<TId, ? extends Iterable<TId>> adjacency, int maxHops) {
        return reach(ids, adjacency, maxHops, null);
    }

    /** Breadth-first reach from every id through {@code adjacency}, up to {@code maxHops}. */
    public static <TId> ReachResult reach(Collection<TId> ids, Function<TId, ? extends Iterable<TId>> adjacency, int maxHops,
                                          Equality<? super TId> comparer) {
        if (maxHops <= 0) throw new IllegalArgumentException("maxHops must be positive");
        Equality<? super TId> cmp = comparer != null ? comparer : Equality.natural();
        double[] sums = new double[maxHops];
        int isolated = 0;
        for (TId start : ids) {
            Set<Equality.Key<TId>> visited = new HashSet<>();
            visited.add(new Equality.Key<>(start, cmp));
            List<TId> frontier = List.of(start);
            int reached = 0;
            for (int hop = 0; hop < maxHops; hop++) {
                List<TId> next = new ArrayList<>();
                for (TId f : frontier)
                    for (TId a : adjacency.apply(f))
                        if (visited.add(new Equality.Key<>(a, cmp))) next.add(a);
                reached += next.size();
                sums[hop] += reached;
                frontier = next;
                if (next.isEmpty()) {
                    for (int h = hop + 1; h < maxHops; h++) sums[h] += reached;
                    break;
                }
            }
            if (reached == 0) isolated++;
        }
        List<Double> means = new ArrayList<>(maxHops);
        for (double s : sums) means.add(ids.isEmpty() ? 0 : s / ids.size());
        return new ReachResult(List.copyOf(means), isolated, ids.size());
    }

    /** Hits that closed because something else was fixed, per direct fix. */
    public static double cascadeYield(int closedByCascade, int directFixes) {
        return directFixes == 0 ? 0 : closedByCascade / (double) directFixes;
    }

    /** Canonical order by the ids' text, compared ordinally (UTF-16 code units), as C# {@code CompareOrdinal}. */
    private static <TId> Pair<TId> canon(Pair<TId> p) {
        return String.valueOf(p.a()).compareTo(String.valueOf(p.b())) <= 0 ? p : new Pair<>(p.b(), p.a());
    }

    // COR-T4 (docs/BUGS.md): unordered, so (a, b) and (b, a) are one pair under the caller's comparer.
    private static <TId> Equality<Pair<TId>> pairEquality(Equality<? super TId> inner) {
        return new Equality<>() {
            @Override
            public boolean equal(Pair<TId> x, Pair<TId> y) {
                return (inner.equal(x.a(), y.a()) && inner.equal(x.b(), y.b()))
                        || (inner.equal(x.a(), y.b()) && inner.equal(x.b(), y.a()));
            }

            @Override
            public int hash(Pair<TId> p) { return inner.hash(p.a()) ^ inner.hash(p.b()); }
        };
    }
}
