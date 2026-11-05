package com.mindattic.corobs.bugs;

import com.mindattic.corobs.Equality;
import com.mindattic.corobs.bench.Bench;
import com.mindattic.corobs.bench.RecallResult;
import com.mindattic.corobs.geometry.Correlithm;
import com.mindattic.corobs.geometry.NCube;
import com.mindattic.corobs.mining.Pattern;
import com.mindattic.corobs.mining.PatternMiner;
import com.mindattic.corobs.mining.PlyPoint;
import com.mindattic.corobs.seeding.SeededPrng;
import com.mindattic.corobs.strings.StringCo;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.function.Function;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** COR-T4 invariants (docs/BUGS.md). The old code lives only in the C# reference; here they pin the fixed behaviour. */
class CorT4Test {

    @Test
    void threshold_no_pattern_member_is_linked_by_a_pair_short_of_the_required_sigma() {
        int n = 4;
        PatternMiner miner = new PatternMiner(6, 5);
        assertTrue(NCube.distanceAtDeviations(n, miner.minDeviations()) < 0, "precondition: μ − 6σ < 0 at N = 4");
        List<PlyPoint<Integer>> points = new ArrayList<>();
        for (int k = 0; k < 5; k++) points.add(new PlyPoint<>(k, new Correlithm(0.1 * k, 0.5, 0.5, 0.5)));

        for (Pattern<Integer> pattern : miner.mine(points))
            for (int id : pattern.members()) {
                Correlithm p = points.get(id).point();
                double best = Double.NEGATIVE_INFINITY;
                for (int o : pattern.members())
                    if (o != id) best = Math.max(best, NCube.deviationsBelow(n, p.distanceTo(points.get(o).point())));
                assertTrue(best >= miner.minDeviations(), String.format(Locale.ROOT,
                        "member %d joined a %.0fσ pattern though its closest partner is only %.2fσ below μ", id, miner.minDeviations(), best));
            }
    }

    @ParameterizedTest
    @ValueSource(doubles = {Double.POSITIVE_INFINITY, Double.NEGATIVE_INFINITY})
    void ring_at_never_returns_a_point_off_the_ring(double t) {
        int n = 32;
        StringCo ring = StringCo.ring(new SeededPrng(42), n);
        Correlithm p;
        try {
            p = ring.at(t);
        } catch (IllegalArgumentException e) {
            return;
        }
        Set<Correlithm> onRing = new HashSet<>();
        int steps = 200_000;
        for (int k = 0; k < steps; k++) onRing.add(ring.at(k / (double) steps));
        assertEquals(2 * n, onRing.size(), "precondition: the grid visits every ring point");
        assertTrue(onRing.contains(p), "At(" + t + ") returned a point the ring never visits (book Ch. IX, p. 123)");
    }

    @Test
    void pairs_a_perfect_predictor_recovers_every_hidden_relationship_even_when_listed_repeatedly() {
        List<Bench.Pair<Integer>> pairs = new ArrayList<>();
        for (int i = 0; i < 20; i++) {
            pairs.add(new Bench.Pair<>(2 * i, 2 * i + 1));
            pairs.add(new Bench.Pair<>(2 * i, 2 * i + 1));
            pairs.add(new Bench.Pair<>(2 * i + 1, 2 * i));
        }
        RecallResult r = Bench.holdoutRecall(pairs, 0.5, 7, oracle(pairs, Equality.natural()));
        assertEquals(1.0, r.recall(), "perfect predictor scored recall " + r.recall() + " (hidden " + r.hidden() + ", recovered " + r.recovered() + ")");
    }

    @Test
    void pairs_one_relationship_under_the_callers_comparer_is_hidden_once() {
        Equality<String> cmp = new Equality<>() {
            @Override public boolean equal(String a, String b) { return a.equalsIgnoreCase(b); }
            @Override public int hash(String v) { return v.toUpperCase(Locale.ROOT).hashCode(); }
        };
        List<Bench.Pair<String>> pairs = new ArrayList<>();
        for (int i = 0; i < 20; i++) {
            pairs.add(new Bench.Pair<>("a" + i, "B" + i));
            pairs.add(new Bench.Pair<>("b" + i, "A" + i));
        }
        RecallResult r = Bench.holdoutRecall(pairs, 0.5, 7, oracle(pairs, cmp), cmp);
        assertEquals(10, r.hidden(), "20 relationships, half hidden; each spelled two ways is still one relationship");
    }

    private static <T> Function<T, Collection<T>> oracle(List<Bench.Pair<T>> pairs, Equality<? super T> cmp) {
        Map<Equality.Key<T>, List<T>> map = new HashMap<>();
        for (Bench.Pair<T> p : pairs) {
            map.computeIfAbsent(new Equality.Key<>(p.a(), cmp), k -> new ArrayList<>()).add(p.b());
            map.computeIfAbsent(new Equality.Key<>(p.b(), cmp), k -> new ArrayList<>()).add(p.a());
        }
        return id -> map.getOrDefault(new Equality.Key<>(id, cmp), List.of());
    }
}
