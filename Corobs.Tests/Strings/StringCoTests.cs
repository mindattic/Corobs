using Corobs.Geometry;
using Corobs.Seeding;
using Corobs.Strings;

namespace Corobs.Tests.Strings;

/// <summary>Ch. VII: distance along the geometry becomes distance in the cube; strangers stay at μ.</summary>
public sealed class StringCoTests
{
    private const int N = 2048; // large so a single string's statistics are tight

    [Test]
    public void Line_distance_grows_as_root_of_separation_and_reaches_mu()
    {
        var line = StringCo.Line(new SeededPrng(11), N);
        var mu = NCube.StandardDistance(N);
        var origin = line.At(0);
        var d1 = origin.DistanceTo(line.At(0.1));
        var d3 = origin.DistanceTo(line.At(0.3));
        var d6 = origin.DistanceTo(line.At(0.6));
        var d10 = origin.DistanceTo(line.At(1.0));
        Assert.That(d1, Is.LessThan(d3).And.LessThan(d6));
        Assert.That(d3, Is.LessThan(d6));
        Assert.That(d6, Is.LessThan(d10));
        Assert.That(d1 / mu, Is.EqualTo(Math.Sqrt(0.1)).Within(0.06), "≈ μ·√|Δt|");
        Assert.That(d10 / mu, Is.EqualTo(1).Within(0.06), "the far ends are at standard distance");
        Assert.That(origin.DistanceTo(origin), Is.EqualTo(0));
    }

    [Test]
    public void Ring_wraps()
    {
        var ring = StringCo.Ring(new SeededPrng(12), N);
        var mu = NCube.StandardDistance(N);
        var origin = ring.At(0);
        Assert.That(origin.DistanceTo(ring.At(0.5)) / mu, Is.EqualTo(1).Within(0.06), "opposite side is μ");
        Assert.That(origin.DistanceTo(ring.At(0.98)), Is.LessThan(origin.DistanceTo(ring.At(0.25))), "0.98 is next to 0");
        Assert.That(ring.At(0.3).DistanceTo(ring.At(1.3)), Is.EqualTo(0), "t is taken mod 1");
    }

    [Test]
    public void Plane_is_isotropic()
    {
        var plane = StringCo.Plane(new SeededPrng(13), N);
        var origin = plane.At(0.5, 0.5);
        var alongX = origin.DistanceTo(plane.At(0.8, 0.5));
        var alongY = origin.DistanceTo(plane.At(0.5, 0.8));
        var diagonal = origin.DistanceTo(plane.At(0.5 + 0.3 / Math.Sqrt(2), 0.5 + 0.3 / Math.Sqrt(2)));
        Assert.That(alongX, Is.EqualTo(alongY).Within(alongY * 0.15));
        Assert.That(diagonal, Is.EqualTo(alongX).Within(alongX * 0.2));
        Assert.That(origin.DistanceTo(plane.At(0.55, 0.5)), Is.LessThan(alongX));
    }

    [Test]
    public void Every_position_is_a_stranger_to_an_unrelated_point()
    {
        var prng = new SeededPrng(14);
        var line = StringCo.Line(prng, N);
        var stranger = Correlithm.Random(prng, N);
        var mu = NCube.StandardDistance(N);
        foreach (var t in new[] { 0.0, 0.25, 0.5, 0.75, 1.0 })
            Assert.That(line.At(t).DistanceTo(stranger) / mu, Is.EqualTo(1).Within(0.06));
    }

    [Test]
    public void Ordinal_positions_are_evenly_spaced()
    {
        var line = StringCo.Line(new SeededPrng(15), N);
        var a = line.AtIndex(0, 26); var b = line.AtIndex(1, 26); var e = line.AtIndex(4, 26); var z = line.AtIndex(25, 26);
        Assert.That(a.DistanceTo(b), Is.LessThan(a.DistanceTo(e)));
        Assert.That(a.DistanceTo(e), Is.LessThan(a.DistanceTo(z)));
    }

    [Test]
    public void Same_seed_same_string()
    {
        var a = StringCo.Plane(new SeededPrng(16), 64).At(0.2, 0.7);
        var b = StringCo.Plane(new SeededPrng(16), 64).At(0.2, 0.7);
        Assert.That(a, Is.EqualTo(b));
    }
}
