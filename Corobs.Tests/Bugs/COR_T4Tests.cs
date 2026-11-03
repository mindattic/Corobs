using Corobs.Geometry;
using Corobs.Mining;
using Corobs.Seeding;
using Corobs.Strings;

namespace Corobs.Tests.Bugs;

/// <summary>COR-T4. Each test asserts an invariant, not an implementation; built with the fix's
/// symbol (docs/BUGS.md) the old code runs and the test fails. The proofs are in docs/BUGS.md.</summary>
public sealed class COR_T4Tests
{
    [Test]
    public void Threshold_no_pattern_member_is_linked_by_a_pair_short_of_the_required_sigma()
    {
        const int n = 4;
        var miner = new PatternMiner(minDeviations: 6, minMembers: 5);
        Assert.That(NCube.DistanceAtDeviations(n, miner.MinDeviations), Is.LessThan(0), "precondition: μ − 6σ < 0 at N = 4");

        var points = Enumerable.Range(0, 5)
            .Select(k => new PlyPoint<int>(k, new Correlithm([0.1 * k, 0.5, 0.5, 0.5])))
            .ToArray();

        foreach (var pattern in miner.Mine(points))
            foreach (var id in pattern.Members)
            {
                var p = points[id].Point;
                var best = pattern.Members.Where(o => o != id).Max(o => NCube.DeviationsBelow(n, p.DistanceTo(points[o].Point)));
                Assert.That(best, Is.GreaterThanOrEqualTo(miner.MinDeviations),
                    $"member {id} joined a {miner.MinDeviations}σ pattern though its closest partner is only {best:F2}σ below μ");
            }
    }

    [TestCase(double.PositiveInfinity)]
    [TestCase(double.NegativeInfinity)]
    public void Ring_At_never_returns_a_point_off_the_ring(double t)
    {
        const int n = 32;
        var ring = StringCo.Ring(new SeededPrng(42), n);

        Correlithm p;
        try { p = ring.At(t); }
        catch (ArgumentOutOfRangeException) { return; }

        // A ring takes exactly 2N distinct points, one per arc between its 2N breakpoints.
        var onRing = new HashSet<Correlithm>();
        const int steps = 200_000;
        for (var k = 0; k < steps; k++) onRing.Add(ring.At(k / (double)steps));
        Assert.That(onRing, Has.Count.EqualTo(2 * n), "precondition: the grid visits every ring point");
        Assert.That(onRing, Does.Contain(p), $"At({t}) returned a point the ring never visits (book Ch. IX, p. 123: exactly on the string)");
    }

    [Test]
    public void Pairs_a_perfect_predictor_recovers_every_hidden_relationship_even_when_listed_repeatedly()
    {
        var pairs = new List<(int, int)>();
        for (var i = 0; i < 20; i++) { pairs.Add((2 * i, 2 * i + 1)); pairs.Add((2 * i, 2 * i + 1)); pairs.Add((2 * i + 1, 2 * i)); }
        var r = Corobs.Bench.Bench.HoldoutRecall(pairs, 0.5, seed: 7, Oracle(pairs, EqualityComparer<int>.Default));
        Assert.That(r.Recall, Is.EqualTo(1.0), $"perfect predictor scored recall {r.Recall:F3} (hidden {r.Hidden}, recovered {r.Recovered})");
    }

    [Test]
    public void Pairs_one_relationship_under_the_callers_comparer_is_hidden_once()
    {
        var cmp = StringComparer.OrdinalIgnoreCase;
        var pairs = new List<(string, string)>();
        for (var i = 0; i < 20; i++) { pairs.Add(($"a{i}", $"B{i}")); pairs.Add(($"b{i}", $"A{i}")); }
        var r = Corobs.Bench.Bench.HoldoutRecall(pairs, 0.5, seed: 7, Oracle(pairs, cmp), cmp);
        Assert.That(r.Hidden, Is.EqualTo(10), "20 relationships, half hidden; each spelled two ways is still one relationship");
    }

    private static Func<T, IReadOnlyCollection<T>> Oracle<T>(IEnumerable<(T A, T B)> pairs, IEqualityComparer<T> cmp) where T : notnull
    {
        var map = new Dictionary<T, List<T>>(cmp);
        foreach (var (a, b) in pairs)
        {
            (map.TryGetValue(a, out var la) ? la : map[a] = []).Add(b);
            (map.TryGetValue(b, out var lb) ? lb : map[b] = []).Add(a);
        }
        return id => map.TryGetValue(id, out var l) ? l : [];
    }
}
