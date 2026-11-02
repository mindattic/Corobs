namespace Corobs.Geometry;

/// <summary>
/// The statistics of the real unit N-cube (Lawrence, <i>Correlithm Object Technology</i>, Ch. II–III).
/// Two points chosen at random are almost always <see cref="StandardDistance"/> apart, with a standard
/// deviation that does not grow with N (Table II-1). Proximity far below that distance is therefore
/// information: <see cref="BitContent"/> says how much (Eq. III-H), <see cref="ProbabilityOfProximity"/>
/// how unlikely by chance (Eq. III-J), <see cref="PointCapacity"/> how many random points fit before
/// two collide (Eq. III-Q). Valid for N of about 20 and up; 50–128 is the working range.
/// </summary>
public static class NCube
{
    /// <summary>σ of the distance between two random points: √(7/120) ≈ 0.2415, independent of N.</summary>
    public const double StandardDeviation = 0.24152294576982397;

    /// <summary>σ of the distance from the midpoint to a random point: √(1/60) ≈ 0.1291.</summary>
    public const double RadiusDeviation = 0.12909944487358055;

    /// <summary>σ of the distance from a corner to a random point: √(1/15) ≈ 0.2582.</summary>
    public const double DiameterDeviation = 0.2581988897471611;

    /// <summary>μ: expected distance between two random points, √(N/6).</summary>
    public static double StandardDistance(int dimensions) => Math.Sqrt(Check(dimensions) / 6.0);

    /// <summary>Expected distance from the midpoint to a random point, √(N/12).</summary>
    public static double StandardRadius(int dimensions) => Math.Sqrt(Check(dimensions) / 12.0);

    /// <summary>Expected distance from a corner to a random point, √(N/3).</summary>
    public static double StandardDiameter(int dimensions) => Math.Sqrt(Check(dimensions) / 3.0);

    /// <summary>Expected distance between two random corners, √(N/2).</summary>
    public static double CornerDistance(int dimensions) => Math.Sqrt(Check(dimensions) / 2.0);

    /// <summary>Midpoint to any corner, exactly √(N/4).</summary>
    public static double HalfDiagonal(int dimensions) => Math.Sqrt(Check(dimensions) / 4.0);

    /// <summary>Opposite corners, exactly √N.</summary>
    public static double MajorDiagonal(int dimensions) => Math.Sqrt(Check(dimensions));

    /// <summary>How many standard deviations below μ a distance lies (negative when beyond μ).</summary>
    public static double DeviationsBelow(int dimensions, double distance)
        => (StandardDistance(dimensions) - distance) / StandardDeviation;

    /// <summary>The distance that lies <paramref name="deviations"/> σ below μ.</summary>
    public static double DistanceAtDeviations(int dimensions, double deviations)
        => StandardDistance(dimensions) - deviations * StandardDeviation;

    /// <summary>Eq. III-H: bits of information in two points lying <paramref name="distance"/> apart,
    /// ((μ − d)/σ)² / ln 2 ≈ 24.75·(μ − d)². Zero at or beyond standard distance. The book's rule of
    /// thumb — a little over four bits per dimension at d = 0 — falls out of this.</summary>
    public static double BitContent(int dimensions, double distance)
    {
        var x = DeviationsBelow(dimensions, distance);
        return x <= 0 ? 0 : x * x / Math.Log(2);
    }

    /// <summary>The distance at which proximity is worth <paramref name="bits"/> bits.</summary>
    public static double DistanceForBits(int dimensions, double bits)
    {
        if (bits < 0) throw new ArgumentOutOfRangeException(nameof(bits));
        return StandardDistance(dimensions) - StandardDeviation * Math.Sqrt(bits * Math.Log(2));
    }

    /// <summary>Eq. III-J: the probability that two random points lie closer than
    /// <paramref name="distance"/>, 10^(−7.45(μ − d)²) = 2^(−bits). One at or beyond μ.</summary>
    public static double ProbabilityOfProximity(int dimensions, double distance)
        => Math.Pow(2, -BitContent(dimensions, distance));

    /// <summary>Eq. III-Q: how many random points can be placed before two are expected to lie
    /// closer than <paramref name="distance"/>, 10^(3.7(μ − d)²).</summary>
    public static double PointCapacity(int dimensions, double distance)
    {
        var gap = StandardDistance(dimensions) - distance;
        return gap <= 0 ? 1 : Math.Pow(10, 3.7 * gap * gap);
    }

    private static int Check(int dimensions)
        => dimensions > 0 ? dimensions : throw new ArgumentOutOfRangeException(nameof(dimensions), "A space needs at least one dimension; the statistics hold from about 20.");
}
