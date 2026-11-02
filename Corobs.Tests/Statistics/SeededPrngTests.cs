using Corobs.Seeding;

namespace Corobs.Tests.Statistics;

public sealed class SeededPrngTests
{
    [Test]
    public void Same_seed_same_stream()
    {
        var a = new SeededPrng(42); var b = new SeededPrng(42);
        for (var i = 0; i < 1000; i++) Assert.That(a.NextUInt64(), Is.EqualTo(b.NextUInt64()));
    }

    [Test]
    public void Different_seeds_differ()
    {
        var a = new SeededPrng(1); var b = new SeededPrng(2);
        Assert.That(Enumerable.Range(0, 16).Select(_ => a.NextUInt64()), Is.Not.EqualTo(Enumerable.Range(0, 16).Select(_ => b.NextUInt64())));
    }

    [Test]
    public void Doubles_are_uniform_on_the_unit_interval()
    {
        var p = new SeededPrng(99);
        var xs = Enumerable.Range(0, 20000).Select(_ => p.NextDouble()).ToArray();
        Assert.That(xs, Has.All.InRange(0.0, 1.0 - double.Epsilon));
        Assert.That(xs.Average(), Is.EqualTo(0.5).Within(0.01));
    }

    [Test]
    public void Derive_is_deterministic_and_independent_of_consumption()
    {
        var a = new SeededPrng(5);
        _ = a.NextUInt64(); _ = a.NextUInt64();
        var b = new SeededPrng(5);
        Assert.That(a.Derive("faction").Seed, Is.EqualTo(b.Derive("faction").Seed));
        Assert.That(a.Derive("faction").Seed, Is.Not.EqualTo(b.Derive("turf").Seed));
        Assert.That(a.Derive("faction").Seed, Is.Not.EqualTo(a.Seed));
    }
}
