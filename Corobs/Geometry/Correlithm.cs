using Corobs.Seeding;

namespace Corobs.Geometry;

/// <summary>
/// A correlithm object: one point in the real unit N-cube, every coordinate in [0, 1]. A CO is a
/// <i>soft token</i> (Ch. IV) — it stands for its datum exactly at its coordinates and, to a degree
/// <see cref="NCube.BitContent"/> quantifies, at every point nearby. Immutable.
/// </summary>
public sealed class Correlithm : IEquatable<Correlithm>
{
    private readonly double[] _c;

    /// <summary>N: the dimensionality of the cube this point lives in. All the N-cube statistics
    /// (<see cref="NCube"/>) are a function of this number.</summary>
    public int Dimensions => _c.Length;

    /// <summary>The coordinate on one dimension, in [0, 1].</summary>
    public double this[int dimension] => _c[dimension];

    /// <summary>All N coordinates, in order.</summary>
    public ReadOnlySpan<double> Coordinates => _c;

    /// <summary>A point at exactly these coordinates; each must lie in [0, 1].</summary>
    public Correlithm(ReadOnlySpan<double> coordinates)
    {
        if (coordinates.Length == 0) throw new ArgumentException("A point needs at least one coordinate.", nameof(coordinates));
        foreach (var v in coordinates)
            if (double.IsNaN(v) || v < 0 || v > 1) throw new ArgumentOutOfRangeException(nameof(coordinates), "Every coordinate must lie in [0, 1].");
        _c = coordinates.ToArray();
    }

    private Correlithm(double[] owned) => _c = owned;

    /// <summary>A point chosen uniformly at random from the whole cube — a fresh token, at standard
    /// distance from every other random token with overwhelming probability.</summary>
    public static Correlithm Random(SeededPrng prng, int dimensions)
    {
        var c = new double[CheckDimensions(dimensions)];
        for (var i = 0; i < c.Length; i++) c[i] = prng.NextDouble();
        return new Correlithm(c);
    }

    /// <summary>The cube's centre, 0.5 in every dimension — where a missing value goes, because the
    /// midpoint is at <see cref="NCube.StandardRadius"/> from everything and carries no bits.</summary>
    public static Correlithm Midpoint(int dimensions)
    {
        var c = new double[CheckDimensions(dimensions)];
        Array.Fill(c, 0.5);
        return new Correlithm(c);
    }

    /// <summary>Euclidean distance squared to <paramref name="other"/>, from the same cube.</summary>
    public double SquaredDistanceTo(Correlithm other)
    {
        CheckSame(other);
        double s = 0;
        var a = _c; var b = other._c;
        for (var i = 0; i < a.Length; i++) { var d = a[i] - b[i]; s += d * d; }
        return s;
    }

    /// <summary>Euclidean distance to <paramref name="other"/> — compare against
    /// <see cref="NCube.StandardDistance"/> to read it as information (<see cref="NCube.BitContent"/>).</summary>
    public double DistanceTo(Correlithm other) => Math.Sqrt(SquaredDistanceTo(other));

    /// <summary>Linear interpolation by <paramref name="fraction"/> from this point toward
    /// <paramref name="other"/>. Note Ch. VII's warning: interpolated points "take a shortcut" and
    /// sit closer than standard distance to third points; use <c>StringCo</c> for sequences.</summary>
    public Correlithm Interpolate(Correlithm other, double fraction)
    {
        CheckSame(other);
        if (fraction < 0 || fraction > 1) throw new ArgumentOutOfRangeException(nameof(fraction));
        var c = new double[_c.Length];
        for (var i = 0; i < c.Length; i++) c[i] = _c[i] + (other._c[i] - _c[i]) * fraction;
        return new Correlithm(c);
    }

    /// <summary>The coordinate-wise mean of a set of points.</summary>
    public static Correlithm Centroid(IReadOnlyCollection<Correlithm> points)
    {
        if (points.Count == 0) throw new ArgumentException("A centroid needs at least one point.", nameof(points));
        double[]? sum = null;
        foreach (var p in points)
        {
            sum ??= new double[p.Dimensions];
            if (sum.Length != p.Dimensions) throw new ArgumentException("All points must share one dimensionality.", nameof(points));
            for (var i = 0; i < sum.Length; i++) sum[i] += p._c[i];
        }
        for (var i = 0; i < sum!.Length; i++) sum[i] /= points.Count;
        return new Correlithm(sum);
    }

    /// <summary>A point that superposes several: their centroid. Each component remains recoverable
    /// — the centroid of K random points lies at about μ·√((K−1)/K)·… closer to each than a random
    /// point would be (Ch. VIII, Superposition).</summary>
    public static Correlithm Superpose(IReadOnlyCollection<Correlithm> points) => Centroid(points);

    /// <summary>True when every coordinate matches exactly — not a proximity test. Two independently
    /// drawn points are, by the book's statistics, never equal; use <see cref="DistanceTo"/> for that.</summary>
    public bool Equals(Correlithm? other) => other is not null && _c.AsSpan().SequenceEqual(other._c);

    /// <inheritdoc cref="Equals(Correlithm?)"/>
    public override bool Equals(object? obj) => Equals(obj as Correlithm);

    /// <summary>Consistent with <see cref="Equals(Correlithm?)"/>: equal points hash equal.</summary>
    public override int GetHashCode()
    {
        var h = new HashCode();
        foreach (var v in _c) h.Add(v);
        return h.ToHashCode();
    }

    /// <summary>Just the dimensionality; coordinates are not meant to be read as text.</summary>
    public override string ToString() => $"CO[{Dimensions}]";

    private void CheckSame(Correlithm other)
    {
        if (other._c.Length != _c.Length) throw new ArgumentException("Points from different spaces have no distance.", nameof(other));
    }

    private static int CheckDimensions(int dimensions)
        => dimensions > 0 ? dimensions : throw new ArgumentOutOfRangeException(nameof(dimensions));
}
