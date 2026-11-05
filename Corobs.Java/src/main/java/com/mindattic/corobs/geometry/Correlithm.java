package com.mindattic.corobs.geometry;

import com.mindattic.corobs.seeding.SeededPrng;

import java.util.Arrays;
import java.util.Collection;

/**
 * A correlithm object: one point in the real unit N-cube, every coordinate in [0, 1]. A CO is a
 * <i>soft token</i> (Ch. IV). Immutable.
 */
public final class Correlithm {
    private final double[] c;

    /** A point at exactly these coordinates; each must lie in [0, 1]. */
    public Correlithm(double... coordinates) {
        if (coordinates.length == 0) throw new IllegalArgumentException("A point needs at least one coordinate.");
        for (double v : coordinates)
            if (Double.isNaN(v) || v < 0 || v > 1) throw new IllegalArgumentException("Every coordinate must lie in [0, 1].");
        c = coordinates.clone();
    }

    private Correlithm(double[] owned, boolean unused) { c = owned; }

    /** N: the dimensionality of the cube this point lives in. */
    public int dimensions() { return c.length; }

    /** The coordinate on one dimension, in [0, 1]. */
    public double coordinate(int dimension) { return c[dimension]; }

    /** All N coordinates, in order (a copy). */
    public double[] coordinates() { return c.clone(); }

    /** A point chosen uniformly at random from the whole cube. */
    public static Correlithm random(SeededPrng prng, int dimensions) {
        double[] c = new double[checkDimensions(dimensions)];
        for (int i = 0; i < c.length; i++) c[i] = prng.nextDouble();
        return new Correlithm(c, true);
    }

    /** The cube's centre, 0.5 in every dimension: where a missing value goes. */
    public static Correlithm midpoint(int dimensions) {
        double[] c = new double[checkDimensions(dimensions)];
        Arrays.fill(c, 0.5);
        return new Correlithm(c, true);
    }

    /** Euclidean distance squared to {@code other}, from the same cube. */
    public double squaredDistanceTo(Correlithm other) {
        checkSame(other);
        double s = 0;
        double[] a = c, b = other.c;
        for (int i = 0; i < a.length; i++) {
            double d = a[i] - b[i];
            s += d * d;
        }
        return s;
    }

    /** Euclidean distance to {@code other}. */
    public double distanceTo(Correlithm other) { return Math.sqrt(squaredDistanceTo(other)); }

    /** Linear interpolation by {@code fraction} from this point toward {@code other} (Ch. VII warns these take
     *  a shortcut; use {@code StringCo} for sequences). */
    public Correlithm interpolate(Correlithm other, double fraction) {
        checkSame(other);
        if (fraction < 0 || fraction > 1) throw new IllegalArgumentException("fraction must lie in [0, 1]");
        double[] r = new double[c.length];
        for (int i = 0; i < r.length; i++) r[i] = c[i] + (other.c[i] - c[i]) * fraction;
        return new Correlithm(r, true);
    }

    /** The coordinate-wise mean of a set of points, summed in iteration order. */
    public static Correlithm centroid(Collection<Correlithm> points) {
        if (points.isEmpty()) throw new IllegalArgumentException("A centroid needs at least one point.");
        double[] sum = null;
        for (Correlithm p : points) {
            if (sum == null) sum = new double[p.dimensions()];
            if (sum.length != p.dimensions()) throw new IllegalArgumentException("All points must share one dimensionality.");
            for (int i = 0; i < sum.length; i++) sum[i] += p.c[i];
        }
        for (int i = 0; i < sum.length; i++) sum[i] /= points.size();
        return new Correlithm(sum);
    }

    /** A point that superposes several: their centroid (Ch. VIII). */
    public static Correlithm superpose(Collection<Correlithm> points) { return centroid(points); }

    /** True when every coordinate matches exactly (as .NET {@code double.Equals}): not a proximity test. */
    @Override
    public boolean equals(Object o) {
        if (!(o instanceof Correlithm other) || other.c.length != c.length) return false;
        for (int i = 0; i < c.length; i++) if (c[i] != other.c[i]) return false;
        return true;
    }

    @Override
    public int hashCode() {
        int h = 1;
        for (double v : c) h = 31 * h + Double.hashCode(v == 0 ? 0.0 : v);
        return h;
    }

    /** Just the dimensionality; coordinates are not meant to be read as text. */
    @Override
    public String toString() { return "CO[" + c.length + "]"; }

    private void checkSame(Correlithm other) {
        if (other.c.length != c.length) throw new IllegalArgumentException("Points from different spaces have no distance.");
    }

    private static int checkDimensions(int dimensions) {
        if (dimensions <= 0) throw new IllegalArgumentException("dimensions must be positive");
        return dimensions;
    }
}
