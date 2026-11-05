using System.Globalization;
using System.Text.Json;
using System.Text.Json.Nodes;
using Corobs.Bench;
using Corobs.Converters;
using Corobs.Geometry;
using Corobs.Mining;
using Corobs.Seeding;
using Corobs.Strings;

namespace Corobs.TestVectors;

/// <summary>Builds conformance/vectors.json: the C# reference's exact outputs that every language port
/// must reproduce. The schema is documented in conformance/README.md.</summary>
public static class Vectors
{
    public static string FindRepoRoot(string start)
    {
        for (var dir = new DirectoryInfo(start); dir is not null; dir = dir.Parent)
            if (Directory.Exists(Path.Combine(dir.FullName, "Corobs.Csharp"))) return dir.FullName;
        throw new DirectoryNotFoundException("No directory above " + start + " holds Corobs.Csharp.");
    }

    public static string Build()
    {
        var doc = new JsonObject
        {
            ["format"] = 1,
            ["generator"] = "Corobs.Csharp/Corobs.TestVectors",
            ["prng"] = Prng(),
            ["derive"] = Derive(),
            ["ncube"] = NCubeStats(),
            ["correlithm"] = CorrelithmOps(),
            ["strings"] = Strings(),
            ["converters"] = Converters(),
            ["mining"] = Mining(),
            ["bench"] = BenchCases(),
        };
        return doc.ToJsonString(new JsonSerializerOptions { WriteIndented = true }).Replace("\r\n", "\n") + "\n";
    }

    private static readonly long[] Seeds = [0, 1, 42, -1, long.MinValue, long.MaxValue, 0x0123456789ABCDEF];

    private static string Bits(double v) => BitConverter.DoubleToInt64Bits(v).ToString("x16", CultureInfo.InvariantCulture);
    private static JsonArray Bits(Correlithm p) => new(p.Coordinates.ToArray().Select(v => (JsonNode)Bits(v)).ToArray());
    private static string S(long v) => v.ToString(CultureInfo.InvariantCulture);
    private static string U(ulong v) => v.ToString(CultureInfo.InvariantCulture);

    private static JsonArray Prng()
    {
        var arr = new JsonArray();
        foreach (var seed in Seeds)
        {
            var u = new SeededPrng(seed);
            var d = new SeededPrng(seed);
            var next = new JsonArray();
            foreach (var max in new[] { 1, 2, 7, 10, 1000, int.MaxValue })
            {
                var p = new SeededPrng(seed);
                next.Add(new JsonObject { ["max"] = max, ["values"] = new JsonArray(Enumerable.Range(0, 8).Select(_ => (JsonNode)p.Next(max)).ToArray()) });
            }
            arr.Add(new JsonObject
            {
                ["seed"] = S(seed),
                ["uint64"] = new JsonArray(Enumerable.Range(0, 8).Select(_ => (JsonNode)U(u.NextUInt64())).ToArray()),
                ["doubles"] = new JsonArray(Enumerable.Range(0, 8).Select(_ => (JsonNode)Bits(d.NextDouble())).ToArray()),
                ["next"] = next,
            });
        }
        return arr;
    }

    private static JsonArray Derive()
    {
        var arr = new JsonArray();
        foreach (var seed in new long[] { 0, 42, -1, long.MinValue })
            foreach (var label in new[] { "", "faction", "turf/42", "é漢字\U0001F642", "a much longer label with spaces and digits 0123456789" })
            {
                var child = new SeededPrng(seed).Derive(label);
                arr.Add(new JsonObject
                {
                    ["seed"] = S(seed),
                    ["label"] = label,
                    ["childSeed"] = S(child.Seed),
                    ["firstUint64"] = U(child.NextUInt64()),
                    ["grandchildSeed"] = S(child.Derive("x").Seed),
                });
            }
        return arr;
    }

    private static JsonObject NCubeStats()
    {
        var cases = new JsonArray();
        foreach (var n in new[] { 1, 4, 12, 20, 64, 100, 128 })
        {
            var mu = NCube.StandardDistance(n);
            var distances = new JsonArray();
            foreach (var d in new[] { 0.0, 0.5, mu / 2, mu - 6 * NCube.StandardDeviation, mu, mu + 1 })
                distances.Add(new JsonObject
                {
                    ["distance"] = d,
                    ["deviationsBelow"] = NCube.DeviationsBelow(n, d),
                    ["bitContent"] = NCube.BitContent(n, d),
                    ["probabilityOfProximity"] = NCube.ProbabilityOfProximity(n, d),
                    ["pointCapacity"] = NCube.PointCapacity(n, d),
                });
            var bits = new JsonArray();
            foreach (var b in new[] { 0.0, 1.0, 20.0, 51.9 })
                bits.Add(new JsonObject { ["bits"] = b, ["distanceForBits"] = NCube.DistanceForBits(n, b) });
            var devs = new JsonArray();
            foreach (var k in new[] { 0.0, 1.0, 6.0 })
                devs.Add(new JsonObject { ["deviations"] = k, ["distance"] = NCube.DistanceAtDeviations(n, k) });
            cases.Add(new JsonObject
            {
                ["n"] = n,
                ["standardDistance"] = mu,
                ["standardRadius"] = NCube.StandardRadius(n),
                ["standardDiameter"] = NCube.StandardDiameter(n),
                ["cornerDistance"] = NCube.CornerDistance(n),
                ["halfDiagonal"] = NCube.HalfDiagonal(n),
                ["majorDiagonal"] = NCube.MajorDiagonal(n),
                ["distances"] = distances,
                ["bitsToDistance"] = bits,
                ["distanceAtDeviations"] = devs,
            });
        }
        return new JsonObject
        {
            ["standardDeviation"] = NCube.StandardDeviation,
            ["radiusDeviation"] = NCube.RadiusDeviation,
            ["diameterDeviation"] = NCube.DiameterDeviation,
            ["cases"] = cases,
        };
    }

    private static JsonObject CorrelithmOps()
    {
        var prng = new SeededPrng(7);
        var a = Correlithm.Random(prng, 8);
        var b = Correlithm.Random(prng, 8);
        var mid = Correlithm.Midpoint(8);
        var interp = new JsonArray();
        foreach (var f in new[] { 0.0, 0.25, 0.5, 1.0 })
            interp.Add(new JsonObject { ["fraction"] = f, ["point"] = Bits(a.Interpolate(b, f)) });
        return new JsonObject
        {
            ["seed"] = "7",
            ["dimensions"] = 8,
            ["a"] = Bits(a),
            ["b"] = Bits(b),
            ["midpoint"] = Bits(mid),
            ["squaredDistance"] = Bits(a.SquaredDistanceTo(b)),
            ["distance"] = Bits(a.DistanceTo(b)),
            ["centroidOfABMidpoint"] = Bits(Correlithm.Centroid([a, b, mid])),
            ["interpolate"] = interp,
        };
    }

    private static JsonObject Strings()
    {
        const int n = 16;
        var line = StringCo.Line(new SeededPrng(11), n);
        var ring = StringCo.Ring(new SeededPrng(12), n);
        var plane = StringCo.Plane(new SeededPrng(13), n);
        JsonArray At(StringCo s, double[] ts) => new(ts.Select(t => (JsonNode)new JsonObject { ["t"] = Bits(t), ["point"] = Bits(s.At(t)) }).ToArray());
        JsonArray Idx(StringCo s, int count) => new(Enumerable.Range(0, count).Select(i => (JsonNode)new JsonObject { ["index"] = i, ["count"] = count, ["point"] = Bits(s.AtIndex(i, count)) }).ToArray());
        var planeAt = new JsonArray();
        foreach (var x in new[] { -0.5, 0.0, 0.3, 0.5, 1.0, 2.0 })
            foreach (var y in new[] { 0.0, 0.7, 1.0 })
                planeAt.Add(new JsonObject { ["x"] = Bits(x), ["y"] = Bits(y), ["point"] = Bits(plane.At(x, y)) });
        return new JsonObject
        {
            ["dimensions"] = n,
            ["line"] = new JsonObject
            {
                ["seed"] = "11",
                ["at"] = At(line, [-1.0, 0.0, 0.1, 0.25, 0.5, 0.75, 0.999, 1.0, 2.0, double.NegativeInfinity, double.PositiveInfinity]),
                ["atIndex"] = Idx(line, 5),
                ["atIndexSingle"] = Idx(line, 1),
            },
            ["ring"] = new JsonObject
            {
                ["seed"] = "12",
                ["at"] = At(ring, [-1.25, -0.25, 0.0, 0.1, 0.5, 0.9, 1.0, 1.75, 1e6 + 0.3]),
                ["atIndex"] = Idx(ring, 5),
            },
            ["plane"] = new JsonObject { ["seed"] = "13", ["at"] = planeAt },
        };
    }

    private static JsonObject Converters()
    {
        const int n = 16;
        var cardinal = new CardinalConverter<string>(new SeededPrng(3), n);
        var cardinalCases = new JsonArray();
        foreach (var key in new[] { "red", "green", "blue", "é漢字\U0001F642", "", "red" })
            cardinalCases.Add(new JsonObject { ["value"] = key, ["point"] = Bits(cardinal.Convert(key)) });

        string[] order = ["low", "mid", "high", "top"];
        var ordinal = new OrdinalConverter<string>(new SeededPrng(5), n, order);
        var ordinalCases = new JsonArray(order.Select(v => (JsonNode)new JsonObject { ["value"] = v, ["point"] = Bits(ordinal.Convert(v)) }).ToArray());

        JsonArray Continuous(ContinuousConverter c, double[] values)
            => new(values.Select(v => (JsonNode)new JsonObject { ["value"] = Bits(v), ["point"] = Bits(c.Convert(v)) }).ToArray());
        var line = new ContinuousConverter(new SeededPrng(6), n, 0, 100);
        var ring = new ContinuousConverter(new SeededPrng(8), n, 0, 24, wraps: true);

        var planar = new PlanarConverter(new SeededPrng(9), n, 0, 10, -5, 5);
        var planarCases = new JsonArray();
        foreach (var (x, y) in new[] { (0.0, -5.0), (5.0, 0.0), (10.0, 5.0), (2.5, 4.0), (-3.0, 9.0), (double.NaN, 1.0) })
            planarCases.Add(new JsonObject { ["x"] = Bits(x), ["y"] = Bits(y), ["point"] = Bits(planar.Convert((x, y))) });

        return new JsonObject
        {
            ["dimensions"] = n,
            ["missing"] = Bits(Correlithm.Midpoint(n)),
            ["cardinal"] = new JsonObject { ["seed"] = "3", ["cases"] = cardinalCases },
            ["ordinal"] = new JsonObject { ["seed"] = "5", ["order"] = new JsonArray(order.Select(o => (JsonNode)o).ToArray()), ["cases"] = ordinalCases },
            ["continuousLine"] = new JsonObject
            {
                ["seed"] = "6", ["min"] = 0, ["max"] = 100, ["wraps"] = false,
                ["cases"] = Continuous(line, [0, 25, 50, 99.9, 100, -10, 150, double.PositiveInfinity, double.NegativeInfinity, double.NaN]),
            },
            ["continuousRing"] = new JsonObject
            {
                ["seed"] = "8", ["min"] = 0, ["max"] = 24, ["wraps"] = true,
                ["cases"] = Continuous(ring, [0, 6, 12, 23.5, 24, 30, -3, double.PositiveInfinity, double.NegativeInfinity, double.NaN]),
            },
            ["planar"] = new JsonObject { ["seed"] = "9", ["minX"] = 0, ["maxX"] = 10, ["minY"] = -5, ["maxY"] = 5, ["cases"] = planarCases },
        };
    }

    private static JsonObject Mining()
    {
        const int n = 64;
        var prng = new SeededPrng(21);
        Correlithm Near(Correlithm c) => c.Interpolate(Correlithm.Random(prng, n), 0.1);
        var fa = Correlithm.Random(prng, n); var fb = Correlithm.Random(prng, n); var fc = Correlithm.Random(prng, n);
        var tx = Correlithm.Random(prng, n); var ty = Correlithm.Random(prng, n);
        var faction = new Dictionary<int, Correlithm>();
        var turf = new Dictionary<int, Correlithm>();
        for (var id = 1; id <= 20; id++)
        {
            faction[id] = id <= 6 ? Near(fa) : id <= 12 ? Near(fb) : id <= 18 ? Near(fc) : Correlithm.Random(prng, n);
            turf[id] = id <= 5 ? Near(tx) : id is >= 7 and <= 11 ? Near(ty) : Correlithm.Random(prng, n);
        }
        // Planted contradictions: a member of each turf-bound faction sits at the mirror image of its turf.
        turf[6] = Mirror(tx);
        turf[12] = Mirror(ty);
        static Correlithm Mirror(Correlithm c) => new(c.Coordinates.ToArray().Select(v => 1 - v).ToArray());

        var miner = new PatternMiner();
        var fp = miner.Mine(faction.Select(kv => new PlyPoint<int>(kv.Key, kv.Value)).ToArray());
        var tp = miner.Mine(turf.Select(kv => new PlyPoint<int>(kv.Key, kv.Value)).ToArray());
        var rules = new RuleMiner().Mine("faction", fp, "turf", tp);
        var plies = new Dictionary<string, IReadOnlyDictionary<int, Correlithm>> { ["faction"] = faction, ["turf"] = turf };
        var hits = new Cue().Find(rules, plies);

        JsonArray Points(Dictionary<int, Correlithm> ply) => new(ply.Select(kv => (JsonNode)new JsonObject { ["id"] = kv.Key, ["point"] = Bits(kv.Value) }).ToArray());
        JsonArray Patterns(IReadOnlyList<Pattern<int>> ps) => new(ps.Select(p => (JsonNode)new JsonObject
        {
            ["members"] = new JsonArray(p.Members.Select(m => (JsonNode)m).ToArray()),
            ["centroid"] = Bits(p.Centroid),
            ["radius"] = Bits(p.Radius),
            ["meanPairDistance"] = Bits(p.MeanPairDistance),
            ["bits"] = p.Bits,
        }).ToArray());

        return new JsonObject
        {
            ["dimensions"] = n,
            ["patternMiner"] = new JsonObject { ["minDeviations"] = miner.MinDeviations, ["minMembers"] = miner.MinMembers },
            ["ruleMiner"] = new JsonObject { ["minSupport"] = 0.8 },
            ["cue"] = new JsonObject { ["targetDeviations"] = 1.0 },
            ["plies"] = new JsonObject { ["faction"] = Points(faction), ["turf"] = Points(turf) },
            ["patterns"] = new JsonObject { ["faction"] = Patterns(fp), ["turf"] = Patterns(tp) },
            ["rules"] = new JsonArray(rules.Select(r => (JsonNode)new JsonObject
            {
                ["sourcePly"] = r.SourcePly,
                ["sourcePattern"] = fp.ToList().IndexOf(r.Source),
                ["targetPly"] = r.TargetPly,
                ["targetPattern"] = tp.ToList().IndexOf(r.Target),
                ["support"] = r.Support,
                ["bits"] = r.Bits,
            }).ToArray()),
            ["hits"] = new JsonArray(hits.Select(h => (JsonNode)new JsonObject
            {
                ["id"] = h.Id,
                ["rule"] = rules.ToList().IndexOf(h.Rule),
                ["sourceDistance"] = Bits(h.SourceDistance),
                ["targetDistance"] = Bits(h.TargetDistance),
                ["bits"] = h.Bits,
                ["rank"] = h.Rank,
            }).ToArray()),
        };
    }

    private static JsonObject BenchCases()
    {
        var pairs = new List<(int A, int B)>();
        for (var i = 1; i <= 21; i++) pairs.Add((i, i % 21 + 1 + (i % 3 == 0 ? 7 : 0)));
        pairs.Add((2, 1)); pairs.Add(pairs[4]); pairs.Add((pairs[9].B, pairs[9].A));

        var truthAdj = new Dictionary<int, List<int>>();
        foreach (var (a, b) in pairs)
        {
            (truthAdj.TryGetValue(a, out var la) ? la : truthAdj[a] = []).Add(b);
            (truthAdj.TryGetValue(b, out var lb) ? lb : truthAdj[b] = []).Add(a);
        }
        IReadOnlyCollection<int> Perfect(int id) => truthAdj.TryGetValue(id, out var l) ? l : [];
        IReadOnlyCollection<int> Partial(int id) => id % 2 == 0 ? Perfect(id) : [id + 100];

        JsonObject Recall(RecallResult r) => new() { ["hidden"] = r.Hidden, ["recovered"] = r.Recovered, ["predicted"] = r.Predicted, ["predictedTrue"] = r.PredictedTrue };
        JsonObject Adj(Func<int, IReadOnlyCollection<int>> f, IEnumerable<int> ids)
        {
            var o = new JsonObject();
            foreach (var id in ids) o[id.ToString(CultureInfo.InvariantCulture)] = new JsonArray(f(id).Select(x => (JsonNode)x).ToArray());
            return o;
        }
        var allIds = Enumerable.Range(1, 40).ToArray();

        var recallCases = new JsonArray();
        foreach (var (name, f) in new[] { ("perfect", (Func<int, IReadOnlyCollection<int>>)Perfect), ("partial", Partial) })
            foreach (var (frac, seed) in new[] { (0.5, 99L), (0.3, 7L) })
                recallCases.Add(new JsonObject
                {
                    ["predictor"] = name,
                    ["holdoutFraction"] = frac,
                    ["seed"] = S(seed),
                    ["result"] = Recall(Bench.Bench.HoldoutRecall(pairs, frac, seed, f)),
                });

        var reachAdj = new Dictionary<int, int[]> { [1] = [2, 3], [2] = [4], [3] = [4, 5], [4] = [], [5] = [1], [6] = [] };
        var reach = Bench.Bench.Reach(reachAdj.Keys.ToArray(), id => reachAdj[id], 3);

        return new JsonObject
        {
            ["pairs"] = new JsonArray(pairs.Select(p => (JsonNode)new JsonArray(p.A, p.B)).ToArray()),
            ["predictors"] = new JsonObject { ["perfect"] = Adj(Perfect, allIds), ["partial"] = Adj(Partial, allIds) },
            ["holdoutRecall"] = recallCases,
            ["reach"] = new JsonObject
            {
                ["adjacency"] = Adj(id => reachAdj[id], reachAdj.Keys),
                ["maxHops"] = 3,
                ["meanReachableByHop"] = new JsonArray(reach.MeanReachableByHop.Select(m => (JsonNode)m).ToArray()),
                ["isolated"] = reach.Isolated,
                ["total"] = reach.Total,
            },
            ["cascadeYield"] = new JsonArray(
                new JsonObject { ["closedByCascade"] = 3, ["directFixes"] = 4, ["yield"] = Bench.Bench.CascadeYield(3, 4) },
                new JsonObject { ["closedByCascade"] = 5, ["directFixes"] = 0, ["yield"] = Bench.Bench.CascadeYield(5, 0) }),
        };
    }
}
