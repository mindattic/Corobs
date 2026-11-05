package com.mindattic.corobs.bench;

import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;

class BenchTest {

    @Test
    void holdout_recall_counts_hidden_pairs_the_predictor_recovers() {
        List<Bench.Pair<String>> pairs = new ArrayList<>();
        for (int i = 0; i < 20; i++) pairs.add(new Bench.Pair<>("a" + i, "b" + i));
        Map<String, List<String>> all = new HashMap<>();
        for (Bench.Pair<String> p : pairs) {
            all.computeIfAbsent(p.a(), k -> new ArrayList<>()).add(p.b());
            all.computeIfAbsent(p.b(), k -> new ArrayList<>()).add(p.a());
        }
        RecallResult perfect = Bench.holdoutRecall(pairs, 0.25, 1, id -> all.getOrDefault(id, List.of()));
        assertEquals(5, perfect.hidden());
        assertEquals(1, perfect.recall());
        assertEquals(1, perfect.precision());
        RecallResult blind = Bench.holdoutRecall(pairs, 0.25, 1, id -> List.of());
        assertEquals(0, blind.recall());
        assertEquals(blind.hidden(), Bench.holdoutRecall(pairs, 0.25, 1, id -> List.<String>of()).hidden());
    }

    @Test
    void reach_counts_hops_and_isolated_records() {
        Map<Integer, List<Integer>> adj = Map.of(1, List.of(2), 2, List.of(1, 3), 3, List.of(2), 4, List.of());
        ReachResult r = Bench.reach(List.of(1, 2, 3, 4), adj::get, 2);
        assertEquals(1, r.isolated());
        assertEquals(4, r.total());
        assertEquals((1 + 2 + 1 + 0) / 4.0, r.meanReachableByHop().get(0));
        assertEquals((2 + 2 + 2 + 0) / 4.0, r.meanReachableByHop().get(1));
    }

    @Test
    void cascade_yield_is_closed_by_cascade_per_direct_fix() {
        assertEquals(1.5, Bench.cascadeYield(6, 4));
        assertEquals(0, Bench.cascadeYield(0, 0));
    }
}
