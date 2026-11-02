using Corobs.Geometry;
using Corobs.Seeding;

namespace Corobs.Tests.Statistics;

/// <summary>Table II-1 and Ch. III, checked against the cube itself.</summary>
public sealed class NCubeTests
{
    [TestCase(64)]
    [TestCase(100)]
    public void Random_points_sit_at_standard_distance_with_the_books_deviation(int n)
    {
        var prng = new SeededPrng(2004);
        var distances = new double[3000];
        for (var i = 0; i < distances.Length; i++)
            distances[i] = Correlithm.Random(prng, n).DistanceTo(Correlithm.Random(prng, n));

        var mean = distances.Average();
        var sd = Math.Sqrt(distances.Sum(d => (d - mean) * (d - mean)) / (distances.Length - 1));

        Assert.That(mean, Is.EqualTo(NCube.StandardDistance(n)).Within(0.03), "μ = √(N/6)");
        Assert.That(sd, Is.EqualTo(NCube.StandardDeviation).Within(0.025), "σ = √(7/120), independent of N");
    }

    [TestCase(64)]
    [TestCase(100)]
    public void Midpoint_and_corner_distances_match_the_table(int n)
    {
        var prng = new SeededPrng(7);
        var mid = Correlithm.Midpoint(n);
        var corner = new Correlithm(Enumerable.Repeat(0.0, n).ToArray());
        var toMid = new double[2000]; var toCorner = new double[2000];
        for (var i = 0; i < toMid.Length; i++)
        {
            var p = Correlithm.Random(prng, n);
            toMid[i] = p.DistanceTo(mid);
            toCorner[i] = p.DistanceTo(corner);
        }
        Assert.That(toMid.Average(), Is.EqualTo(NCube.StandardRadius(n)).Within(0.02), "standard radius √(N/12)");
        Assert.That(toCorner.Average(), Is.EqualTo(NCube.StandardDiameter(n)).Within(0.03), "standard diameter √(N/3)");
        Assert.That(NCube.HalfDiagonal(n), Is.EqualTo(mid.DistanceTo(corner)).Within(1e-12));
    }

    [Test]
    public void Bit_content_follows_equation_III_H()
    {
        const int n = 100;
        var mu = NCube.StandardDistance(n);
        Assert.That(NCube.BitContent(n, mu), Is.EqualTo(0));
        Assert.That(NCube.BitContent(n, mu + 1), Is.EqualTo(0), "beyond μ carries nothing");
        // 24.75·(μ−d)² is the book's rounded form of ((μ−d)/σ)²/ln 2.
        Assert.That(NCube.BitContent(n, mu - 1), Is.EqualTo(24.75).Within(0.1));
        // Rule of thumb: a little over four bits per dimension at d = 0.
        Assert.That(NCube.BitContent(n, 0) / n, Is.EqualTo(4.12).Within(0.02));
        Assert.That(NCube.DistanceForBits(n, 24.75), Is.EqualTo(mu - 1).Within(0.005));
    }

    [Test]
    public void Probability_of_proximity_is_two_to_the_minus_bits()
    {
        const int n = 100;
        var mu = NCube.StandardDistance(n);
        Assert.That(NCube.ProbabilityOfProximity(n, mu), Is.EqualTo(1));
        // Eq. III-J: 10^(−7.45(μ−d)²); at μ−d = 0.5 → 10^−1.86.
        Assert.That(Math.Log10(NCube.ProbabilityOfProximity(n, mu - 0.5)), Is.EqualTo(-1.86).Within(0.02));
    }

    [Test]
    public void Point_capacity_follows_equation_III_Q()
    {
        // Book: N=96, d=1.0 → about 10^33 points before a pair falls within 1.0 of each other.
        Assert.That(Math.Log10(NCube.PointCapacity(96, 1.0)), Is.EqualTo(33.3).Within(0.3));
        Assert.That(NCube.PointCapacity(96, NCube.StandardDistance(96)), Is.EqualTo(1));
    }

    [Test]
    public void Deviations_and_distances_round_trip()
    {
        const int n = 64;
        var d = NCube.DistanceAtDeviations(n, 6);
        Assert.That(NCube.DeviationsBelow(n, d), Is.EqualTo(6).Within(1e-9));
        Assert.That(NCube.BitContent(n, d), Is.EqualTo(36 / Math.Log(2)).Within(1e-9), "6σ ≈ 52 bits");
    }
}
