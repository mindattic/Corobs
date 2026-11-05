package com.mindattic.corobs;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.mindattic.corobs.bench.Bench;
import com.mindattic.corobs.bench.RecallResult;
import com.mindattic.corobs.bench.ReachResult;
import com.mindattic.corobs.converters.CardinalConverter;
import com.mindattic.corobs.converters.ContinuousConverter;
import com.mindattic.corobs.converters.OrdinalConverter;
import com.mindattic.corobs.converters.PlanarConverter;
import com.mindattic.corobs.geometry.Correlithm;
import com.mindattic.corobs.geometry.NCube;
import com.mindattic.corobs.mining.Cue;
import com.mindattic.corobs.mining.Hit;
import com.mindattic.corobs.mining.Pattern;
import com.mindattic.corobs.mining.PatternMiner;
import com.mindattic.corobs.mining.PlyPoint;
import com.mindattic.corobs.mining.Rule;
import com.mindattic.corobs.mining.RuleMiner;
import com.mindattic.corobs.seeding.SeededPrng;
import com.mindattic.corobs.strings.StringCo;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Function;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assertions.fail;

/** Reproduces conformance/vectors.json, the C# reference's exact outputs (rules in conformance/README.md). */
class ConformanceTest {
    private static JsonNode v;

    @BeforeAll
    static void load() throws IOException {
        String p = System.getProperty("corobs.vectors");
        Path path = Path.of(p != null ? p : "../conformance/vectors.json");
        v = new ObjectMapper().readTree(Files.readString(path));
        assertEquals(1, v.get("format").asInt(), "vectors format");
    }

    // ---- encoding helpers -------------------------------------------------------------------------------

    private static double bits(JsonNode hex) { return Double.longBitsToDouble(Long.parseUnsignedLong(hex.asText(), 16)); }

    private static String hex(double d) { return String.format("%016x", Double.doubleToRawLongBits(d)); }

    private static void exact(JsonNode expectedHex, double actual, String what) {
        assertEquals(expectedHex.asText(), hex(actual), what);
    }

    private static void point(JsonNode expected, Correlithm actual, String what) {
        assertEquals(expected.size(), actual.dimensions(), what + ": dimensions");
        for (int i = 0; i < expected.size(); i++) exact(expected.get(i), actual.coordinate(i), what + "[" + i + "]");
    }

    private static void close(double expected, double actual, String what) {
        if (expected == actual) return;
        double diff = Math.abs(expected - actual);
        if (diff <= 1e-300 || diff <= 1e-12 * Math.abs(expected)) return;
        fail(what + ": expected " + expected + " but was " + actual);
    }

    private static long seed(JsonNode n) { return Long.parseLong(n.asText()); }

    // ---- sections ---------------------------------------------------------------------------------------

    @Test
    void prng() {
        for (JsonNode c : v.get("prng")) {
            long s = seed(c.get("seed"));
            SeededPrng u = new SeededPrng(s), d = new SeededPrng(s);
            for (JsonNode e : c.get("uint64")) assertEquals(Long.parseUnsignedLong(e.asText()), u.nextUInt64(), "uint64 seed " + s);
            for (JsonNode e : c.get("doubles")) exact(e, d.nextDouble(), "double seed " + s);
            for (JsonNode n : c.get("next")) {
                int max = n.get("max").asInt();
                SeededPrng p = new SeededPrng(s);
                for (JsonNode e : n.get("values")) assertEquals(e.asInt(), p.next(max), "next(" + max + ") seed " + s);
            }
        }
    }

    @Test
    void derive() {
        for (JsonNode c : v.get("derive")) {
            String label = c.get("label").asText();
            SeededPrng child = new SeededPrng(seed(c.get("seed"))).derive(label);
            assertEquals(seed(c.get("childSeed")), child.seed(), "child seed of '" + label + "'");
            assertEquals(seed(c.get("grandchildSeed")), child.derive("x").seed(), "grandchild seed of '" + label + "'");
            assertEquals(Long.parseUnsignedLong(c.get("firstUint64").asText()), child.nextUInt64(), "first word of '" + label + "'");
        }
    }

    @Test
    void ncube() {
        JsonNode s = v.get("ncube");
        close(s.get("standardDeviation").asDouble(), NCube.STANDARD_DEVIATION, "σ");
        close(s.get("radiusDeviation").asDouble(), NCube.RADIUS_DEVIATION, "radius σ");
        close(s.get("diameterDeviation").asDouble(), NCube.DIAMETER_DEVIATION, "diameter σ");
        for (JsonNode c : s.get("cases")) {
            int n = c.get("n").asInt();
            close(c.get("standardDistance").asDouble(), NCube.standardDistance(n), "μ N=" + n);
            close(c.get("standardRadius").asDouble(), NCube.standardRadius(n), "radius N=" + n);
            close(c.get("standardDiameter").asDouble(), NCube.standardDiameter(n), "diameter N=" + n);
            close(c.get("cornerDistance").asDouble(), NCube.cornerDistance(n), "corner N=" + n);
            close(c.get("halfDiagonal").asDouble(), NCube.halfDiagonal(n), "half diagonal N=" + n);
            close(c.get("majorDiagonal").asDouble(), NCube.majorDiagonal(n), "major diagonal N=" + n);
            for (JsonNode d : c.get("distances")) {
                double dist = d.get("distance").asDouble();
                String w = " N=" + n + " d=" + dist;
                close(d.get("deviationsBelow").asDouble(), NCube.deviationsBelow(n, dist), "deviationsBelow" + w);
                close(d.get("bitContent").asDouble(), NCube.bitContent(n, dist), "bitContent" + w);
                close(d.get("probabilityOfProximity").asDouble(), NCube.probabilityOfProximity(n, dist), "probability" + w);
                close(d.get("pointCapacity").asDouble(), NCube.pointCapacity(n, dist), "capacity" + w);
            }
            for (JsonNode b : c.get("bitsToDistance"))
                close(b.get("distanceForBits").asDouble(), NCube.distanceForBits(n, b.get("bits").asDouble()), "distanceForBits N=" + n);
            for (JsonNode k : c.get("distanceAtDeviations"))
                close(k.get("distance").asDouble(), NCube.distanceAtDeviations(n, k.get("deviations").asDouble()), "distanceAtDeviations N=" + n);
        }
    }

    @Test
    void correlithm() {
        JsonNode c = v.get("correlithm");
        int n = c.get("dimensions").asInt();
        SeededPrng prng = new SeededPrng(seed(c.get("seed")));
        Correlithm a = Correlithm.random(prng, n), b = Correlithm.random(prng, n), mid = Correlithm.midpoint(n);
        point(c.get("a"), a, "a");
        point(c.get("b"), b, "b");
        point(c.get("midpoint"), mid, "midpoint");
        exact(c.get("squaredDistance"), a.squaredDistanceTo(b), "squared distance");
        exact(c.get("distance"), a.distanceTo(b), "distance");
        point(c.get("centroidOfABMidpoint"), Correlithm.centroid(List.of(a, b, mid)), "centroid");
        for (JsonNode i : c.get("interpolate"))
            point(i.get("point"), a.interpolate(b, i.get("fraction").asDouble()), "interpolate " + i.get("fraction").asDouble());
    }

    @Test
    void strings() {
        JsonNode s = v.get("strings");
        int n = s.get("dimensions").asInt();
        StringCo line = StringCo.line(new SeededPrng(seed(s.get("line").get("seed"))), n);
        StringCo ring = StringCo.ring(new SeededPrng(seed(s.get("ring").get("seed"))), n);
        StringCo plane = StringCo.plane(new SeededPrng(seed(s.get("plane").get("seed"))), n);
        for (JsonNode c : s.get("line").get("at")) point(c.get("point"), line.at(bits(c.get("t"))), "line.at(" + bits(c.get("t")) + ")");
        for (String key : new String[] {"atIndex", "atIndexSingle"})
            for (JsonNode c : s.get("line").get(key))
                point(c.get("point"), line.atIndex(c.get("index").asInt(), c.get("count").asInt()), "line." + key);
        for (JsonNode c : s.get("ring").get("at")) point(c.get("point"), ring.at(bits(c.get("t"))), "ring.at(" + bits(c.get("t")) + ")");
        for (JsonNode c : s.get("ring").get("atIndex"))
            point(c.get("point"), ring.atIndex(c.get("index").asInt(), c.get("count").asInt()), "ring.atIndex");
        for (JsonNode c : s.get("plane").get("at")) {
            double x = bits(c.get("x")), y = bits(c.get("y"));
            point(c.get("point"), plane.at(x, y), "plane.at(" + x + ", " + y + ")");
        }
    }

    @Test
    void converters() {
        JsonNode s = v.get("converters");
        int n = s.get("dimensions").asInt();
        Correlithm missing = Correlithm.midpoint(n);
        point(s.get("missing"), missing, "missing");

        CardinalConverter<String> cardinal = new CardinalConverter<>(new SeededPrng(seed(s.get("cardinal").get("seed"))), n);
        for (JsonNode c : s.get("cardinal").get("cases"))
            point(c.get("point"), cardinal.convert(c.get("value").asText()), "cardinal '" + c.get("value").asText() + "'");
        assertEquals(missing, cardinal.convert(null));

        List<String> order = new ArrayList<>();
        for (JsonNode o : s.get("ordinal").get("order")) order.add(o.asText());
        OrdinalConverter<String> ordinal = new OrdinalConverter<>(new SeededPrng(seed(s.get("ordinal").get("seed"))), n, order);
        for (JsonNode c : s.get("ordinal").get("cases"))
            point(c.get("point"), ordinal.convert(c.get("value").asText()), "ordinal '" + c.get("value").asText() + "'");

        for (String key : new String[] {"continuousLine", "continuousRing"}) {
            JsonNode k = s.get(key);
            ContinuousConverter cc = new ContinuousConverter(new SeededPrng(seed(k.get("seed"))), n,
                    k.get("min").asDouble(), k.get("max").asDouble(), k.get("wraps").asBoolean());
            for (JsonNode c : k.get("cases")) {
                double value = bits(c.get("value"));
                point(c.get("point"), cc.convert(value), key + "(" + value + ")");
            }
            assertEquals(missing, cc.convert(null));
        }

        JsonNode pl = s.get("planar");
        PlanarConverter planar = new PlanarConverter(new SeededPrng(seed(pl.get("seed"))), n,
                pl.get("minX").asDouble(), pl.get("maxX").asDouble(), pl.get("minY").asDouble(), pl.get("maxY").asDouble());
        for (JsonNode c : pl.get("cases")) {
            double x = bits(c.get("x")), y = bits(c.get("y"));
            point(c.get("point"), planar.convert(new PlanarConverter.Position(x, y)), "planar(" + x + ", " + y + ")");
        }
        assertEquals(missing, planar.convert(null));
    }

    @Test
    void mining() {
        JsonNode s = v.get("mining");
        Map<String, Map<Integer, Correlithm>> plies = new LinkedHashMap<>();
        Map<String, List<PlyPoint<Integer>>> plyPoints = new LinkedHashMap<>();
        for (Iterator<Map.Entry<String, JsonNode>> it = s.get("plies").fields(); it.hasNext(); ) {
            Map.Entry<String, JsonNode> ply = it.next();
            Map<Integer, Correlithm> map = new LinkedHashMap<>();
            List<PlyPoint<Integer>> list = new ArrayList<>();
            for (JsonNode e : ply.getValue()) {
                double[] c = new double[e.get("point").size()];
                for (int i = 0; i < c.length; i++) c[i] = bits(e.get("point").get(i));
                Correlithm p = new Correlithm(c);
                map.put(e.get("id").asInt(), p);
                list.add(new PlyPoint<>(e.get("id").asInt(), p));
            }
            plies.put(ply.getKey(), map);
            plyPoints.put(ply.getKey(), list);
        }

        JsonNode pm = s.get("patternMiner");
        PatternMiner miner = new PatternMiner(pm.get("minDeviations").asDouble(), pm.get("minMembers").asInt());
        Map<String, List<Pattern<Integer>>> patterns = new LinkedHashMap<>();
        for (String ply : List.of("faction", "turf")) {
            List<Pattern<Integer>> found = miner.mine(plyPoints.get(ply));
            patterns.put(ply, found);
            JsonNode expected = s.get("patterns").get(ply);
            assertEquals(expected.size(), found.size(), ply + ": pattern count");
            for (int i = 0; i < found.size(); i++) {
                JsonNode e = expected.get(i);
                Pattern<Integer> p = found.get(i);
                String w = ply + " pattern " + i;
                List<Integer> members = new ArrayList<>();
                for (JsonNode m : e.get("members")) members.add(m.asInt());
                assertEquals(members, p.members(), w + ": members");
                point(e.get("centroid"), p.centroid(), w + ": centroid");
                exact(e.get("radius"), p.radius(), w + ": radius");
                exact(e.get("meanPairDistance"), p.meanPairDistance(), w + ": mean pair distance");
                close(e.get("bits").asDouble(), p.bits(), w + ": bits");
            }
        }

        List<Rule<Integer>> rules = new RuleMiner(s.get("ruleMiner").get("minSupport").asDouble())
                .mine("faction", patterns.get("faction"), "turf", patterns.get("turf"));
        JsonNode er = s.get("rules");
        assertEquals(er.size(), rules.size(), "rule count");
        for (int i = 0; i < rules.size(); i++) {
            JsonNode e = er.get(i);
            Rule<Integer> r = rules.get(i);
            assertEquals(e.get("sourcePly").asText(), r.sourcePly());
            assertEquals(e.get("targetPly").asText(), r.targetPly());
            assertTrue(patterns.get(r.sourcePly()).get(e.get("sourcePattern").asInt()) == r.source(), "rule " + i + ": source pattern");
            assertTrue(patterns.get(r.targetPly()).get(e.get("targetPattern").asInt()) == r.target(), "rule " + i + ": target pattern");
            close(e.get("support").asDouble(), r.support(), "rule " + i + ": support");
            close(e.get("bits").asDouble(), r.bits(), "rule " + i + ": bits");
        }

        List<Hit<Integer>> hits = new Cue(s.get("cue").get("targetDeviations").asDouble()).find(rules, plies);
        JsonNode eh = s.get("hits");
        assertEquals(eh.size(), hits.size(), "hit count");
        for (int i = 0; i < hits.size(); i++) {
            JsonNode e = eh.get(i);
            Hit<Integer> h = hits.get(i);
            assertEquals(e.get("id").asInt(), h.id(), "hit " + i + ": id");
            assertTrue(rules.get(e.get("rule").asInt()) == h.rule(), "hit " + i + ": rule");
            exact(e.get("sourceDistance"), h.sourceDistance(), "hit " + i + ": source distance");
            exact(e.get("targetDistance"), h.targetDistance(), "hit " + i + ": target distance");
            close(e.get("bits").asDouble(), h.bits(), "hit " + i + ": bits");
            assertEquals(e.get("rank").asInt(), h.rank(), "hit " + i + ": rank");
        }
    }

    private static Function<Integer, List<Integer>> adjacency(JsonNode map) {
        Map<Integer, List<Integer>> m = new LinkedHashMap<>();
        for (Iterator<Map.Entry<String, JsonNode>> it = map.fields(); it.hasNext(); ) {
            Map.Entry<String, JsonNode> e = it.next();
            List<Integer> l = new ArrayList<>();
            for (JsonNode x : e.getValue()) l.add(x.asInt());
            m.put(Integer.parseInt(e.getKey()), l);
        }
        return id -> m.getOrDefault(id, List.of());
    }

    @Test
    void bench() {
        JsonNode s = v.get("bench");
        List<Bench.Pair<Integer>> pairs = new ArrayList<>();
        for (JsonNode p : s.get("pairs")) pairs.add(new Bench.Pair<>(p.get(0).asInt(), p.get(1).asInt()));

        for (JsonNode c : s.get("holdoutRecall")) {
            String name = c.get("predictor").asText();
            double fraction = c.get("holdoutFraction").asDouble();
            RecallResult r = Bench.holdoutRecall(pairs, fraction, seed(c.get("seed")), adjacency(s.get("predictors").get(name)));
            JsonNode e = c.get("result");
            String w = name + " @ " + fraction;
            assertEquals(e.get("hidden").asInt(), r.hidden(), w + ": hidden");
            assertEquals(e.get("recovered").asInt(), r.recovered(), w + ": recovered");
            assertEquals(e.get("predicted").asInt(), r.predicted(), w + ": predicted");
            assertEquals(e.get("predictedTrue").asInt(), r.predictedTrue(), w + ": predicted true");
        }

        JsonNode rc = s.get("reach");
        List<Integer> ids = new ArrayList<>();
        for (Iterator<String> it = rc.get("adjacency").fieldNames(); it.hasNext(); ) ids.add(Integer.parseInt(it.next()));
        ReachResult reach = Bench.reach(ids, adjacency(rc.get("adjacency")), rc.get("maxHops").asInt());
        JsonNode means = rc.get("meanReachableByHop");
        assertEquals(means.size(), reach.meanReachableByHop().size(), "reach hops");
        for (int i = 0; i < means.size(); i++) close(means.get(i).asDouble(), reach.meanReachableByHop().get(i), "reach hop " + i);
        assertEquals(rc.get("isolated").asInt(), reach.isolated(), "reach isolated");
        assertEquals(rc.get("total").asInt(), reach.total(), "reach total");

        for (JsonNode c : s.get("cascadeYield"))
            close(c.get("yield").asDouble(), Bench.cascadeYield(c.get("closedByCascade").asInt(), c.get("directFixes").asInt()), "cascade yield");
    }
}
