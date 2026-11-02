using Corobs.Geometry;
using Corobs.Seeding;

namespace Corobs.Strings;

/// <summary>
/// A string CO (Ch. VII): a lower-dimensional geometry — a line, a ring, a plane — embedded in the
/// N-cube so that distance along the geometry is reflected as distance in the cube, rising from zero
/// to standard distance as positions move apart, while every position stays at standard distance from
/// any unrelated random point.
/// <para>Construction follows the book's advice to "distribute the anomalies randomly": each
/// dimension carries two random values and switches between them at its own random breakpoint along
/// the geometry. Two positions then differ in exactly the dimensions whose breakpoint lies between
/// them, so the expected squared distance is μ² times the fraction of such dimensions — √|Δt|·μ on a
/// line, √(2Δ)·μ around a ring (Δ ≤ ½), and isotropic in the plane. No interpolation is involved, so
/// no position "takes a shortcut" toward third points.</para>
/// </summary>
public sealed class StringCo
{
    private enum Kind { Line, Ring, Plane }

    private readonly Kind _kind;
    private readonly double[] _a, _b, _o;
    private readonly double[]? _dx, _dy;

    public int Dimensions => _a.Length;

    private StringCo(Kind kind, double[] a, double[] b, double[] o, double[]? dx, double[]? dy)
        => (_kind, _a, _b, _o, _dx, _dy) = (kind, a, b, o, dx, dy);

    /// <summary>A line segment parameterised by t ∈ [0, 1]. Distance between t and t′ ≈ μ·√|t − t′|.</summary>
    public static StringCo Line(SeededPrng prng, int dimensions)
    {
        var (a, b) = Values(prng, dimensions);
        var o = new double[dimensions];
        for (var i = 0; i < dimensions; i++) o[i] = prng.NextDouble();
        return new StringCo(Kind.Line, a, b, o, null, null);
    }

    /// <summary>A closed ring parameterised by t ∈ [0, 1) with 0 ≡ 1 — for hours, headings, seasons.
    /// Distance between t and t′ ≈ μ·√(2Δ) where Δ is the circular gap (≤ ½).</summary>
    public static StringCo Ring(SeededPrng prng, int dimensions)
    {
        var (a, b) = Values(prng, dimensions);
        var o = new double[dimensions];
        for (var i = 0; i < dimensions; i++) o[i] = prng.NextDouble();
        return new StringCo(Kind.Ring, a, b, o, null, null);
    }

    /// <summary>A unit square parameterised by (x, y) ∈ [0, 1]². Each dimension watches a random
    /// direction, so distance grows with planar separation in every direction alike — the symmetric
    /// "cone" of Fig. VII-10, without the troughs of concatenated 1-D strings (Fig. VII-11).</summary>
    public static StringCo Plane(SeededPrng prng, int dimensions)
    {
        var (a, b) = Values(prng, dimensions);
        var o = new double[dimensions];
        var dx = new double[dimensions];
        var dy = new double[dimensions];
        for (var i = 0; i < dimensions; i++)
        {
            var theta = prng.NextDouble() * 2 * Math.PI;
            dx[i] = Math.Cos(theta);
            dy[i] = Math.Sin(theta);
            var min = Math.Min(0, dx[i]) + Math.Min(0, dy[i]);
            var max = Math.Max(0, dx[i]) + Math.Max(0, dy[i]);
            o[i] = min + prng.NextDouble() * (max - min);
        }
        return new StringCo(Kind.Plane, a, b, o, dx, dy);
    }

    /// <summary>The point at position t on a line (clamped to [0, 1]) or a ring (taken mod 1).</summary>
    public Correlithm At(double t)
    {
        if (_kind == Kind.Plane) throw new InvalidOperationException("A planar string CO takes two coordinates.");
        if (double.IsNaN(t)) throw new ArgumentOutOfRangeException(nameof(t));
        var c = new double[Dimensions];
        if (_kind == Kind.Line)
        {
            t = Math.Clamp(t, 0, 1);
            for (var i = 0; i < c.Length; i++) c[i] = t < _o[i] ? _a[i] : _b[i];
        }
        else
        {
            for (var i = 0; i < c.Length; i++)
            {
                var phase = t - _o[i];
                phase -= Math.Floor(phase);
                c[i] = phase < 0.5 ? _a[i] : _b[i];
            }
        }
        return new Correlithm(c);
    }

    /// <summary>The point at (x, y) on a plane, each clamped to [0, 1].</summary>
    public Correlithm At(double x, double y)
    {
        if (_kind != Kind.Plane) throw new InvalidOperationException("Only a planar string CO takes two coordinates.");
        if (double.IsNaN(x) || double.IsNaN(y)) throw new ArgumentOutOfRangeException(nameof(x));
        x = Math.Clamp(x, 0, 1); y = Math.Clamp(y, 0, 1);
        var c = new double[Dimensions];
        for (var i = 0; i < c.Length; i++)
        {
            var p = x * _dx![i] + y * _dy![i];
            c[i] = p < _o[i] ? _a[i] : _b[i];
        }
        return new Correlithm(c);
    }

    /// <summary>The <paramref name="index"/>-th of <paramref name="count"/> evenly spaced positions —
    /// an ordinal set such as an alphabet, a rank or a tier (Fig. VII-8).</summary>
    public Correlithm AtIndex(int index, int count)
    {
        if (count <= 0) throw new ArgumentOutOfRangeException(nameof(count));
        if (index < 0 || index >= count) throw new ArgumentOutOfRangeException(nameof(index));
        if (_kind == Kind.Ring) return At(index / (double)count);
        return At(count == 1 ? 0 : index / (double)(count - 1));
    }

    private static (double[] A, double[] B) Values(SeededPrng prng, int dimensions)
    {
        if (dimensions <= 0) throw new ArgumentOutOfRangeException(nameof(dimensions));
        var a = new double[dimensions];
        var b = new double[dimensions];
        for (var i = 0; i < dimensions; i++) { a[i] = prng.NextDouble(); b[i] = prng.NextDouble(); }
        return (a, b);
    }
}
