package com.mindattic.corobs.strings;

import com.mindattic.corobs.geometry.Correlithm;
import com.mindattic.corobs.seeding.SeededPrng;

/**
 * A string CO (Ch. VII): a line, a ring or a plane embedded in the N-cube so that distance along the geometry
 * is reflected as distance in the cube, while every position stays at standard distance from unrelated points.
 * Each dimension carries two random values and switches between them at its own random breakpoint.
 */
public final class StringCo {
    private enum Kind { LINE, RING, PLANE }

    private final Kind kind;
    private final double[] a, b, o, dx, dy;

    private StringCo(Kind kind, double[] a, double[] b, double[] o, double[] dx, double[] dy) {
        this.kind = kind; this.a = a; this.b = b; this.o = o; this.dx = dx; this.dy = dy;
    }

    /** N: the dimensionality of the cube this geometry is embedded in. */
    public int dimensions() { return a.length; }

    /** A line segment parameterised by t ∈ [0, 1]. Distance between t and t′ ≈ μ·√|t − t′|. */
    public static StringCo line(SeededPrng prng, int dimensions) {
        double[][] ab = values(prng, dimensions);
        double[] o = new double[dimensions];
        for (int i = 0; i < dimensions; i++) o[i] = prng.nextDouble();
        return new StringCo(Kind.LINE, ab[0], ab[1], o, null, null);
    }

    /** A closed ring parameterised by t ∈ [0, 1) with 0 ≡ 1. Distance ≈ μ·√(2Δ), Δ the circular gap (≤ ½). */
    public static StringCo ring(SeededPrng prng, int dimensions) {
        double[][] ab = values(prng, dimensions);
        double[] o = new double[dimensions];
        for (int i = 0; i < dimensions; i++) o[i] = prng.nextDouble();
        return new StringCo(Kind.RING, ab[0], ab[1], o, null, null);
    }

    /** A unit square parameterised by (x, y) ∈ [0, 1]²; each dimension watches a random direction (Fig. VII-10). */
    public static StringCo plane(SeededPrng prng, int dimensions) {
        double[][] ab = values(prng, dimensions);
        double[] o = new double[dimensions], dx = new double[dimensions], dy = new double[dimensions];
        for (int i = 0; i < dimensions; i++) {
            double theta = prng.nextDouble() * 2 * Math.PI;
            dx[i] = StrictMath.cos(theta);
            dy[i] = StrictMath.sin(theta);
            double min = Math.min(0, dx[i]) + Math.min(0, dy[i]);
            double max = Math.max(0, dx[i]) + Math.max(0, dy[i]);
            o[i] = min + prng.nextDouble() * (max - min);
        }
        return new StringCo(Kind.PLANE, ab[0], ab[1], o, dx, dy);
    }

    /** The point at position t on a line (clamped to [0, 1]) or a ring (taken mod 1). */
    public Correlithm at(double t) {
        if (kind == Kind.PLANE) throw new IllegalStateException("A planar string CO takes two coordinates.");
        if (Double.isNaN(t)) throw new IllegalArgumentException("t is NaN");
        double[] c = new double[dimensions()];
        if (kind == Kind.LINE) {
            t = clamp(t);
            for (int i = 0; i < c.length; i++) c[i] = t < o[i] ? a[i] : b[i];
        } else {
            // COR-T4 (docs/BUGS.md): infinity has no phase on a ring.
            if (Double.isInfinite(t)) throw new IllegalArgumentException("t is infinite; a ring has no position there");
            for (int i = 0; i < c.length; i++) {
                double phase = t - o[i];
                phase -= Math.floor(phase);
                c[i] = phase < 0.5 ? a[i] : b[i];
            }
        }
        return new Correlithm(c);
    }

    /** The point at (x, y) on a plane, each clamped to [0, 1]. */
    public Correlithm at(double x, double y) {
        if (kind != Kind.PLANE) throw new IllegalStateException("Only a planar string CO takes two coordinates.");
        if (Double.isNaN(x) || Double.isNaN(y)) throw new IllegalArgumentException("x or y is NaN");
        x = clamp(x);
        y = clamp(y);
        double[] c = new double[dimensions()];
        for (int i = 0; i < c.length; i++) {
            double p = x * dx[i] + y * dy[i];
            c[i] = p < o[i] ? a[i] : b[i];
        }
        return new Correlithm(c);
    }

    /** The {@code index}-th of {@code count} evenly spaced positions: an ordinal set (Fig. VII-8). */
    public Correlithm atIndex(int index, int count) {
        if (count <= 0) throw new IllegalArgumentException("count must be positive");
        if (index < 0 || index >= count) throw new IllegalArgumentException("index out of range");
        if (kind == Kind.RING) return at(index / (double) count);
        return at(count == 1 ? 0 : index / (double) (count - 1));
    }

    private static double clamp(double v) { return v < 0 ? 0 : v > 1 ? 1 : v; }

    private static double[][] values(SeededPrng prng, int dimensions) {
        if (dimensions <= 0) throw new IllegalArgumentException("dimensions must be positive");
        double[] a = new double[dimensions], b = new double[dimensions];
        for (int i = 0; i < dimensions; i++) {
            a[i] = prng.nextDouble();
            b[i] = prng.nextDouble();
        }
        return new double[][] {a, b};
    }
}
