package com.mindattic.corobs.mining;

import com.mindattic.corobs.geometry.Correlithm;
import com.mindattic.corobs.geometry.NCube;
import com.mindattic.corobs.seeding.SeededPrng;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import java.util.stream.IntStream;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class MiningTest {
    private static final int N = 64;

    private static Correlithm near(Correlithm centre, SeededPrng prng, double jitter) {
        double[] c = new double[centre.dimensions()];
        for (int i = 0; i < c.length; i++)
            c[i] = Math.max(0, Math.min(1, centre.coordinate(i) + (prng.nextDouble() - 0.5) * 2 * jitter));
        return new Correlithm(c);
    }

    @Test
    void a_planted_cluster_among_random_points_is_the_only_pattern() {
        SeededPrng prng = new SeededPrng(100);
        List<PlyPoint<Integer>> points = new ArrayList<>();
        for (int i = 0; i < 1000; i++) points.add(new PlyPoint<>(i, Correlithm.random(prng, N)));
        Correlithm centre = Correlithm.random(prng, N);
        for (int i = 1000; i < 1006; i++) points.add(new PlyPoint<>(i, near(centre, prng, 0.05)));

        List<Pattern<Integer>> patterns = new PatternMiner(6, 5).mine(points);

        assertEquals(1, patterns.size());
        assertEquals(List.of(1000, 1001, 1002, 1003, 1004, 1005), patterns.get(0).members());
        assertTrue(patterns.get(0).bits() > NCube.bitContent(N, NCube.distanceAtDeviations(N, 6)));
        assertTrue(patterns.get(0).radius() < patterns.get(0).meanPairDistance());
    }

    @Test
    void random_points_alone_yield_no_pattern() {
        SeededPrng prng = new SeededPrng(101);
        List<PlyPoint<Integer>> points = new ArrayList<>();
        for (int i = 0; i < 1500; i++) points.add(new PlyPoint<>(i, Correlithm.random(prng, N)));
        assertTrue(new PatternMiner().mine(points).isEmpty());
    }

    private static List<PlyPoint<Integer>> make() {
        SeededPrng p = new SeededPrng(102);
        List<PlyPoint<Integer>> pts = new ArrayList<>();
        for (int i = 0; i < 300; i++) pts.add(new PlyPoint<>(i, i < 8 ? near(Correlithm.midpoint(N), p, 0.05) : Correlithm.random(p, N)));
        return pts;
    }

    @Test
    void mining_is_deterministic() {
        List<Pattern<Integer>> a = new PatternMiner().mine(make()), b = new PatternMiner().mine(make());
        assertEquals(a.stream().map(Pattern::members).collect(Collectors.toList()), b.stream().map(Pattern::members).collect(Collectors.toList()));
        assertEquals(a.stream().map(Pattern::bits).collect(Collectors.toList()), b.stream().map(Pattern::bits).collect(Collectors.toList()));
    }

    @Test
    void a_rule_emerges_and_the_one_member_that_breaks_it_is_the_top_hit() {
        SeededPrng prng = new SeededPrng(103);
        Correlithm cs = Correlithm.random(prng, N);
        Correlithm ct = Correlithm.random(prng, N);
        List<PlyPoint<Integer>> s = new ArrayList<>(), t = new ArrayList<>();
        for (int id = 1; id <= 10; id++) s.add(new PlyPoint<>(id, near(cs, prng, 0.05)));
        for (int id = 1; id <= 9; id++) t.add(new PlyPoint<>(id, near(ct, prng, 0.05)));
        t.add(new PlyPoint<>(10, Correlithm.random(prng, N)));
        for (int id = 11; id <= 40; id++) {
            s.add(new PlyPoint<>(id, Correlithm.random(prng, N)));
            t.add(new PlyPoint<>(id, Correlithm.random(prng, N)));
        }

        PatternMiner miner = new PatternMiner();
        List<Pattern<Integer>> ps = miner.mine(s), pt = miner.mine(t);
        assertEquals(1, ps.size());
        assertEquals(1, pt.size());

        List<Rule<Integer>> rules = new RuleMiner(0.8).mine("faction", ps, "turf", pt);
        assertEquals(1, rules.size());
        assertEquals(0.9, rules.get(0).support(), 1e-9);

        Map<String, Map<Integer, Correlithm>> plies = new HashMap<>();
        plies.put("faction", s.stream().collect(Collectors.toMap(PlyPoint::id, PlyPoint::point)));
        plies.put("turf", t.stream().collect(Collectors.toMap(PlyPoint::id, PlyPoint::point)));
        List<Hit<Integer>> hits = new Cue().find(rules, plies);
        assertEquals(1, hits.size());
        assertEquals(10, hits.get(0).id());
        assertEquals(1, hits.get(0).rank());
        assertTrue(hits.get(0).bits() > 0);
        assertTrue(hits.get(0).targetDistance() > NCube.distanceAtDeviations(N, 1));
    }

    @Test
    void a_rule_needs_support() {
        SeededPrng prng = new SeededPrng(104);
        Correlithm cs = Correlithm.random(prng, N), ct = Correlithm.random(prng, N);
        List<PlyPoint<Integer>> s = IntStream.rangeClosed(1, 10).mapToObj(id -> new PlyPoint<>(id, near(cs, prng, 0.05))).collect(Collectors.toList());
        List<PlyPoint<Integer>> t = new ArrayList<>();
        for (int id = 1; id <= 5; id++) t.add(new PlyPoint<>(id, near(ct, prng, 0.05)));
        for (int id = 6; id <= 10; id++) t.add(new PlyPoint<>(id, Correlithm.random(prng, N)));
        PatternMiner miner = new PatternMiner();
        assertTrue(new RuleMiner(0.8).mine("a", miner.mine(s), "b", miner.mine(t)).isEmpty(), "half the members is not a rule");
        assertThrows(IllegalArgumentException.class, () -> new RuleMiner().mine("a", miner.mine(s), "a", miner.mine(t)));
    }
}
