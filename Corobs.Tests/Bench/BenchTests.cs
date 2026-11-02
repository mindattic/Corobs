using Corobs.Bench;

namespace Corobs.Tests.Bench;

public sealed class BenchTests
{
    [Test]
    public void Holdout_recall_counts_hidden_pairs_the_predictor_recovers()
    {
        var pairs = new List<(string, string)>();
        for (var i = 0; i < 20; i++) pairs.Add(($"a{i}", $"b{i}"));
        // A predictor that knows every pair recovers everything with perfect precision.
        var all = pairs.SelectMany(p => new[] { (p.Item1, p.Item2), (p.Item2, p.Item1) }).ToLookup(x => x.Item1, x => x.Item2);
        var perfect = Corobs.Bench.Bench.HoldoutRecall(pairs, 0.25, seed: 1, id => all[id].ToArray());
        Assert.That(perfect.Hidden, Is.EqualTo(5));
        Assert.That(perfect.Recall, Is.EqualTo(1));
        Assert.That(perfect.Precision, Is.EqualTo(1));
        // A predictor that knows nothing recovers nothing.
        var blind = Corobs.Bench.Bench.HoldoutRecall(pairs, 0.25, seed: 1, _ => []);
        Assert.That(blind.Recall, Is.EqualTo(0));
        // Same seed, same hidden set.
        Assert.That(Corobs.Bench.Bench.HoldoutRecall(pairs, 0.25, seed: 1, _ => []).Hidden, Is.EqualTo(blind.Hidden));
    }

    [Test]
    public void Reach_counts_hops_and_isolated_records()
    {
        var adj = new Dictionary<int, int[]> { [1] = [2], [2] = [1, 3], [3] = [2], [4] = [] };
        var r = Corobs.Bench.Bench.Reach([1, 2, 3, 4], id => adj[id], maxHops: 2);
        Assert.That(r.Isolated, Is.EqualTo(1));
        Assert.That(r.Total, Is.EqualTo(4));
        Assert.That(r.MeanReachableByHop[0], Is.EqualTo((1 + 2 + 1 + 0) / 4.0));
        Assert.That(r.MeanReachableByHop[1], Is.EqualTo((2 + 2 + 2 + 0) / 4.0));
    }

    [Test]
    public void Cascade_yield_is_closed_by_cascade_per_direct_fix()
    {
        Assert.That(Corobs.Bench.Bench.CascadeYield(6, 4), Is.EqualTo(1.5));
        Assert.That(Corobs.Bench.Bench.CascadeYield(0, 0), Is.EqualTo(0));
    }
}
