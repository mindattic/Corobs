package com.mindattic.corobs.geometry;

/**
 * The statistics of the real unit N-cube (Lawrence, <i>Correlithm Object Technology</i>, Ch. II–III).
 * Two random points are almost always {@link #standardDistance} apart, with a standard deviation that does
 * not grow with N (Table II-1). Valid for N of about 20 and up; 50–128 is the working range.
 */
public final class NCube {
    private NCube() {}

    /** σ of the distance between two random points: √(7/120) ≈ 0.2415, independent of N. */
    public static final double STANDARD_DEVIATION = 0.24152294576982397;

    /** σ of the distance from the midpoint to a random point: √(1/60) ≈ 0.1291. */
    public static final double RADIUS_DEVIATION = 0.12909944487358055;

    /** σ of the distance from a corner to a random point: √(1/15) ≈ 0.2582. */
    public static final double DIAMETER_DEVIATION = 0.2581988897471611;

    /** μ: expected distance between two random points, √(N/6). */
    public static double standardDistance(int dimensions) { return Math.sqrt(check(dimensions) / 6.0); }

    /** Expected distance from the midpoint to a random point, √(N/12). */
    public static double standardRadius(int dimensions) { return Math.sqrt(check(dimensions) / 12.0); }

    /** Expected distance from a corner to a random point, √(N/3). */
    public static double standardDiameter(int dimensions) { return Math.sqrt(check(dimensions) / 3.0); }

    /** Expected distance between two random corners, √(N/2). */
    public static double cornerDistance(int dimensions) { return Math.sqrt(check(dimensions) / 2.0); }

    /** Midpoint to any corner, exactly √(N/4). */
    public static double halfDiagonal(int dimensions) { return Math.sqrt(check(dimensions) / 4.0); }

    /** Opposite corners, exactly √N. */
    public static double majorDiagonal(int dimensions) { return Math.sqrt(check(dimensions)); }

    /** How many standard deviations below μ a distance lies (negative when beyond μ). */
    public static double deviationsBelow(int dimensions, double distance) {
        return (standardDistance(dimensions) - distance) / STANDARD_DEVIATION;
    }

    /** The distance that lies {@code deviations} σ below μ. */
    public static double distanceAtDeviations(int dimensions, double deviations) {
        return standardDistance(dimensions) - deviations * STANDARD_DEVIATION;
    }

    /** Eq. III-H: bits of information in two points lying {@code distance} apart, ((μ − d)/σ)² / ln 2.
     *  Zero at or beyond standard distance. */
    public static double bitContent(int dimensions, double distance) {
        double x = deviationsBelow(dimensions, distance);
        return x <= 0 ? 0 : x * x / StrictMath.log(2);
    }

    /** The distance at which proximity is worth {@code bits} bits. */
    public static double distanceForBits(int dimensions, double bits) {
        if (bits < 0) throw new IllegalArgumentException("bits must not be negative");
        return standardDistance(dimensions) - STANDARD_DEVIATION * Math.sqrt(bits * StrictMath.log(2));
    }

    /** Eq. III-J: the probability that two random points lie closer than {@code distance}, 2^(−bits). */
    public static double probabilityOfProximity(int dimensions, double distance) {
        return StrictMath.pow(2, -bitContent(dimensions, distance));
    }

    /** Eq. III-Q: how many random points fit before two are expected closer than {@code distance},
     *  10^(3.7(μ − d)²). */
    public static double pointCapacity(int dimensions, double distance) {
        double gap = standardDistance(dimensions) - distance;
        return gap <= 0 ? 1 : StrictMath.pow(10, 3.7 * gap * gap);
    }

    private static int check(int dimensions) {
        if (dimensions <= 0)
            throw new IllegalArgumentException("A space needs at least one dimension; the statistics hold from about 20.");
        return dimensions;
    }
}
