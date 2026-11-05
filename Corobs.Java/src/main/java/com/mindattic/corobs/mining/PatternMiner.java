package com.mindattic.corobs.mining;

import com.mindattic.corobs.Equality;
import com.mindattic.corobs.geometry.Correlithm;
import com.mindattic.corobs.geometry.NCube;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Finds the clusters on one ply that are far tighter than chance: two points are linked when they lie at least
 * {@link #minDeviations()} σ below standard distance, linked points are joined by union-find, and a component
 * with at least {@link #minMembers()} members is a proposed {@link Pattern}. Deterministic.
 */
public final class PatternMiner {
    private final double minDeviations;
    private final int minMembers;

    /** 6σ (≈ 52 bits) and at least 5 members. */
    public PatternMiner() { this(6, 5); }

    /** Links points {@code minDeviations} σ below standard distance and keeps clusters of {@code minMembers}. */
    public PatternMiner(double minDeviations, int minMembers) {
        if (minDeviations <= 0) throw new IllegalArgumentException("minDeviations must be positive");
        if (minMembers < 2) throw new IllegalArgumentException("minMembers must be at least 2");
        this.minDeviations = minDeviations;
        this.minMembers = minMembers;
    }

    /** The linking threshold, in σ below standard distance. */
    public double minDeviations() { return minDeviations; }

    /** The smallest cluster size kept as a pattern. */
    public int minMembers() { return minMembers; }

    /** Patterns among {@code points}, ids in natural order. */
    @SuppressWarnings({"unchecked", "rawtypes"})
    public <TId> List<Pattern<TId>> mine(List<PlyPoint<TId>> points) {
        return mine(points, (Comparator<? super TId>) (Comparator) Comparator.naturalOrder(), null);
    }

    /** The patterns found among {@code points} (all on one ply), ordered by bits descending then by first member
     *  under {@code order}; {@code equality} is passed to each {@link Pattern}. */
    public <TId> List<Pattern<TId>> mine(List<PlyPoint<TId>> points, Comparator<? super TId> order, Equality<? super TId> equality) {
        if (points.size() < minMembers) return List.of();
        int n = points.get(0).point().dimensions();
        List<PlyPoint<TId>> sorted = new ArrayList<>(points);
        sorted.sort((x, y) -> order.compare(x.id(), y.id()));
        double threshold = NCube.distanceAtDeviations(n, minDeviations);
        // COR-T4 (docs/BUGS.md): distance is never negative, so a negative threshold links nothing.
        if (threshold < 0) return List.of();
        double thresholdSq = threshold * threshold;

        int[] parent = new int[sorted.size()];
        for (int i = 0; i < parent.length; i++) parent[i] = i;
        for (int i = 0; i < sorted.size(); i++) {
            Correlithm pi = sorted.get(i).point();
            for (int j = i + 1; j < sorted.size(); j++)
                if (pi.squaredDistanceTo(sorted.get(j).point()) <= thresholdSq) union(parent, i, j);
        }

        Map<Integer, List<Integer>> groups = new LinkedHashMap<>();
        for (int i = 0; i < sorted.size(); i++) groups.computeIfAbsent(find(parent, i), k -> new ArrayList<>()).add(i);

        List<Pattern<TId>> result = new ArrayList<>();
        for (List<Integer> members : groups.values()) {
            if (members.size() < minMembers) continue;
            List<Correlithm> pts = new ArrayList<>(members.size());
            List<TId> ids = new ArrayList<>(members.size());
            for (int i : members) {
                pts.add(sorted.get(i).point());
                ids.add(sorted.get(i).id());
            }
            Correlithm centroid = Correlithm.centroid(pts);
            double radius = Double.NEGATIVE_INFINITY;
            for (Correlithm p : pts) radius = Math.max(radius, p.distanceTo(centroid));
            double sum = 0;
            int pairs = 0;
            for (int a = 0; a < pts.size(); a++)
                for (int b = a + 1; b < pts.size(); b++) {
                    sum += pts.get(a).distanceTo(pts.get(b));
                    pairs++;
                }
            double mean = sum / pairs;
            result.add(new Pattern<>(ids, centroid, radius, mean, NCube.bitContent(n, mean), equality));
        }

        result.sort(Comparator.<Pattern<TId>>comparingDouble(Pattern::bits).reversed()
                .thenComparing((x, y) -> order.compare(x.members().get(0), y.members().get(0))));
        return List.copyOf(result);
    }

    private static int find(int[] parent, int i) {
        while (parent[i] != i) {
            parent[i] = parent[parent[i]];
            i = parent[i];
        }
        return i;
    }

    private static void union(int[] parent, int a, int b) {
        int ra = find(parent, a), rb = find(parent, b);
        if (ra == rb) return;
        if (ra < rb) parent[rb] = ra; else parent[ra] = rb;
    }
}
