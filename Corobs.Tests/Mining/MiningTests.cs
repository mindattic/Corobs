using Corobs.Geometry;
using Corobs.Mining;
using Corobs.Seeding;

namespace Corobs.Tests.Mining;

public sealed class MiningTests
{
    private const int N = 64;

    private static Correlithm Near(Correlithm centre, SeededPrng prng, double jitter)
    {
        var c = new double[centre.Dimensions];
        for (var i = 0; i < c.Length; i++) c[i] = Math.Clamp(centre[i] + (prng.NextDouble() - 0.5) * 2 * jitter, 0, 1);
        return new Correlithm(c);
    }

    [Test]
    public void A_planted_cluster_among_random_points_is_the_only_pattern()
    {
        var prng = new SeededPrng(100);
        var points = new List<PlyPoint<int>>();
        for (var i = 0; i < 1000; i++) points.Add(new PlyPoint<int>(i, Correlithm.Random(prng, N)));
        var centre = Correlithm.Random(prng, N);
        for (var i = 1000; i < 1006; i++) points.Add(new PlyPoint<int>(i, Near(centre, prng, 0.05)));

        var patterns = new PatternMiner(minDeviations: 6, minMembers: 5).Mine(points);

        Assert.That(patterns, Has.Count.EqualTo(1));
        Assert.That(patterns[0].Members, Is.EquivalentTo(Enumerable.Range(1000, 6)));
        Assert.That(patterns[0].Bits, Is.GreaterThan(NCube.BitContent(N, NCube.DistanceAtDeviations(N, 6))));
        Assert.That(patterns[0].Radius, Is.LessThan(patterns[0].MeanPairDistance));
    }

    [Test]
    public void Random_points_alone_yield_no_pattern()
    {
        var prng = new SeededPrng(101);
        var points = Enumerable.Range(0, 1500).Select(i => new PlyPoint<int>(i, Correlithm.Random(prng, N))).ToArray();
        Assert.That(new PatternMiner().Mine(points), Is.Empty);
    }

    [Test]
    public void Mining_is_deterministic()
    {
        PlyPoint<int>[] Make() { var p = new SeededPrng(102); return Enumerable.Range(0, 300).Select(i => new PlyPoint<int>(i, i < 8 ? Near(Correlithm.Midpoint(N), p, 0.05) : Correlithm.Random(p, N))).ToArray(); }
        var a = new PatternMiner().Mine(Make()); var b = new PatternMiner().Mine(Make());
        Assert.That(a.Select(p => p.Members), Is.EqualTo(b.Select(p => p.Members)));
        Assert.That(a.Select(p => p.Bits), Is.EqualTo(b.Select(p => p.Bits)));
    }

    [Test]
    public void A_rule_emerges_and_the_one_member_that_breaks_it_is_the_top_hit()
    {
        var prng = new SeededPrng(103);
        var cs = Correlithm.Random(prng, N); // where the faction sits on ply s
        var ct = Correlithm.Random(prng, N); // where its turf sits on ply t

        var s = new List<PlyPoint<int>>(); var t = new List<PlyPoint<int>>();
        for (var id = 1; id <= 10; id++) s.Add(new PlyPoint<int>(id, Near(cs, prng, 0.05)));       // ten members of one faction
        for (var id = 1; id <= 9; id++) t.Add(new PlyPoint<int>(id, Near(ct, prng, 0.05)));        // nine share the turf
        t.Add(new PlyPoint<int>(10, Correlithm.Random(prng, N)));                                   // one lives somewhere unrelated
        for (var id = 11; id <= 40; id++) { s.Add(new PlyPoint<int>(id, Correlithm.Random(prng, N))); t.Add(new PlyPoint<int>(id, Correlithm.Random(prng, N))); }

        var miner = new PatternMiner();
        var ps = miner.Mine(s); var pt = miner.Mine(t);
        Assert.That(ps, Has.Count.EqualTo(1)); Assert.That(pt, Has.Count.EqualTo(1));

        var rules = new RuleMiner(0.8).Mine("faction", ps, "turf", pt);
        Assert.That(rules, Has.Count.EqualTo(1));
        Assert.That(rules[0].Support, Is.EqualTo(0.9).Within(1e-9));

        var plies = new Dictionary<string, IReadOnlyDictionary<int, Correlithm>>
        {
            ["faction"] = s.ToDictionary(p => p.Id, p => p.Point),
            ["turf"] = t.ToDictionary(p => p.Id, p => p.Point),
        };
        var hits = new Cue().Find(rules, plies);
        Assert.That(hits, Has.Count.EqualTo(1));
        Assert.That(hits[0].Id, Is.EqualTo(10));
        Assert.That(hits[0].Rank, Is.EqualTo(1));
        Assert.That(hits[0].Bits, Is.GreaterThan(0));
        Assert.That(hits[0].TargetDistance, Is.GreaterThan(NCube.DistanceAtDeviations(N, 1)));
    }

    [Test]
    public void A_rule_needs_support()
    {
        var prng = new SeededPrng(104);
        var cs = Correlithm.Random(prng, N); var ct = Correlithm.Random(prng, N);
        var s = Enumerable.Range(1, 10).Select(id => new PlyPoint<int>(id, Near(cs, prng, 0.05))).ToList();
        var t = Enumerable.Range(1, 5).Select(id => new PlyPoint<int>(id, Near(ct, prng, 0.05)))
            .Concat(Enumerable.Range(6, 5).Select(id => new PlyPoint<int>(id, Correlithm.Random(prng, N)))).ToList();
        var miner = new PatternMiner();
        Assert.That(new RuleMiner(0.8).Mine("a", miner.Mine(s), "b", miner.Mine(t)), Is.Empty, "half the members is not a rule");
        Assert.That(() => new RuleMiner().Mine("a", miner.Mine(s), "a", miner.Mine(t)), Throws.ArgumentException);
    }
}
