package com.mindattic.corobs.geometry;

import com.mindattic.corobs.seeding.SeededPrng;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import java.util.Arrays;

import static org.junit.jupiter.api.Assertions.assertEquals;

/** Table II-1 and Ch. III, checked against the cube itself. */
class NCubeTest {

    @ParameterizedTest
    @ValueSource(ints = {64, 100})
    void random_points_sit_at_standard_distance_with_the_books_deviation(int n) {
        SeededPrng prng = new SeededPrng(2004);
        double[] distances = new double[3000];
        for (int i = 0; i < distances.length; i++)
            distances[i] = Correlithm.random(prng, n).distanceTo(Correlithm.random(prng, n));
        double mean = Arrays.stream(distances).average().orElseThrow();
        double sd = Math.sqrt(Arrays.stream(distances).map(d -> (d - mean) * (d - mean)).sum() / (distances.length - 1));
        assertEquals(NCube.standardDistance(n), mean, 0.03, "μ = √(N/6)");
        assertEquals(NCube.STANDARD_DEVIATION, sd, 0.025, "σ = √(7/120), independent of N");
    }

    @ParameterizedTest
    @ValueSource(ints = {64, 100})
    void midpoint_and_corner_distances_match_the_table(int n) {
        SeededPrng prng = new SeededPrng(7);
        Correlithm mid = Correlithm.midpoint(n);
        Correlithm corner = new Correlithm(new double[n]);
        double[] toMid = new double[2000], toCorner = new double[2000];
        for (int i = 0; i < toMid.length; i++) {
            Correlithm p = Correlithm.random(prng, n);
            toMid[i] = p.distanceTo(mid);
            toCorner[i] = p.distanceTo(corner);
        }
        assertEquals(NCube.standardRadius(n), Arrays.stream(toMid).average().orElseThrow(), 0.02, "standard radius √(N/12)");
        assertEquals(NCube.standardDiameter(n), Arrays.stream(toCorner).average().orElseThrow(), 0.03, "standard diameter √(N/3)");
        assertEquals(mid.distanceTo(corner), NCube.halfDiagonal(n), 1e-12);
    }

    @Test
    void bit_content_follows_equation_III_H() {
        int n = 100;
        double mu = NCube.standardDistance(n);
        assertEquals(0, NCube.bitContent(n, mu));
        assertEquals(0, NCube.bitContent(n, mu + 1), "beyond μ carries nothing");
        assertEquals(24.75, NCube.bitContent(n, mu - 1), 0.1);
        assertEquals(4.12, NCube.bitContent(n, 0) / n, 0.02, "a little over four bits per dimension at d = 0");
        assertEquals(mu - 1, NCube.distanceForBits(n, 24.75), 0.005);
    }

    @Test
    void probability_of_proximity_is_two_to_the_minus_bits() {
        int n = 100;
        double mu = NCube.standardDistance(n);
        assertEquals(1, NCube.probabilityOfProximity(n, mu));
        assertEquals(-1.86, Math.log10(NCube.probabilityOfProximity(n, mu - 0.5)), 0.02, "Eq. III-J");
    }

    @Test
    void point_capacity_follows_equation_III_Q() {
        assertEquals(33.3, Math.log10(NCube.pointCapacity(96, 1.0)), 0.3, "about 10^33 points at N = 96, d = 1");
        assertEquals(1, NCube.pointCapacity(96, NCube.standardDistance(96)));
    }

    @Test
    void deviations_and_distances_round_trip() {
        int n = 64;
        double d = NCube.distanceAtDeviations(n, 6);
        assertEquals(6, NCube.deviationsBelow(n, d), 1e-9);
        assertEquals(36 / Math.log(2), NCube.bitContent(n, d), 1e-9, "6σ ≈ 52 bits");
    }
}
