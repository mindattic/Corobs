package com.mindattic.corobs.strings;

import com.mindattic.corobs.geometry.Correlithm;
import com.mindattic.corobs.geometry.NCube;
import com.mindattic.corobs.seeding.SeededPrng;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

/** Ch. VII: distance along the geometry becomes distance in the cube; strangers stay at μ. */
class StringCoTest {
    private static final int N = 2048;

    @Test
    void line_distance_grows_as_root_of_separation_and_reaches_mu() {
        StringCo line = StringCo.line(new SeededPrng(11), N);
        double mu = NCube.standardDistance(N);
        Correlithm origin = line.at(0);
        double d1 = origin.distanceTo(line.at(0.1)), d3 = origin.distanceTo(line.at(0.3));
        double d6 = origin.distanceTo(line.at(0.6)), d10 = origin.distanceTo(line.at(1.0));
        assertTrue(d1 < d3 && d3 < d6 && d6 < d10);
        assertEquals(Math.sqrt(0.1), d1 / mu, 0.06, "≈ μ·√|Δt|");
        assertEquals(1, d10 / mu, 0.06, "the far ends are at standard distance");
        assertEquals(0, origin.distanceTo(origin));
    }

    @Test
    void ring_wraps() {
        StringCo ring = StringCo.ring(new SeededPrng(12), N);
        double mu = NCube.standardDistance(N);
        Correlithm origin = ring.at(0);
        assertEquals(1, origin.distanceTo(ring.at(0.5)) / mu, 0.06, "opposite side is μ");
        assertTrue(origin.distanceTo(ring.at(0.98)) < origin.distanceTo(ring.at(0.25)), "0.98 is next to 0");
        assertEquals(0, ring.at(0.3).distanceTo(ring.at(1.3)), "t is taken mod 1");
    }

    @Test
    void plane_is_isotropic() {
        StringCo plane = StringCo.plane(new SeededPrng(13), N);
        Correlithm origin = plane.at(0.5, 0.5);
        double alongX = origin.distanceTo(plane.at(0.8, 0.5));
        double alongY = origin.distanceTo(plane.at(0.5, 0.8));
        double diagonal = origin.distanceTo(plane.at(0.5 + 0.3 / Math.sqrt(2), 0.5 + 0.3 / Math.sqrt(2)));
        assertEquals(alongY, alongX, alongY * 0.15);
        assertEquals(alongX, diagonal, alongX * 0.2);
        assertTrue(origin.distanceTo(plane.at(0.55, 0.5)) < alongX);
    }

    @Test
    void every_position_is_a_stranger_to_an_unrelated_point() {
        SeededPrng prng = new SeededPrng(14);
        StringCo line = StringCo.line(prng, N);
        Correlithm stranger = Correlithm.random(prng, N);
        double mu = NCube.standardDistance(N);
        for (double t : new double[] {0.0, 0.25, 0.5, 0.75, 1.0})
            assertEquals(1, line.at(t).distanceTo(stranger) / mu, 0.06);
    }

    @Test
    void ordinal_positions_are_evenly_spaced() {
        StringCo line = StringCo.line(new SeededPrng(15), N);
        Correlithm a = line.atIndex(0, 26), b = line.atIndex(1, 26), e = line.atIndex(4, 26), z = line.atIndex(25, 26);
        assertTrue(a.distanceTo(b) < a.distanceTo(e));
        assertTrue(a.distanceTo(e) < a.distanceTo(z));
    }

    @Test
    void same_seed_same_string() {
        assertEquals(StringCo.plane(new SeededPrng(16), 64).at(0.2, 0.7), StringCo.plane(new SeededPrng(16), 64).at(0.2, 0.7));
    }

    @Test
    void wrong_arity_and_nan_throw() {
        StringCo line = StringCo.line(new SeededPrng(17), 8);
        assertThrows(IllegalStateException.class, () -> line.at(0.1, 0.2));
        assertThrows(IllegalStateException.class, () -> StringCo.plane(new SeededPrng(18), 8).at(0.1));
        assertThrows(IllegalArgumentException.class, () -> line.at(Double.NaN));
    }
}
