package com.mindattic.corobs.geometry;

import com.mindattic.corobs.seeding.SeededPrng;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class CorrelithmTest {

    @Test
    void coordinates_must_lie_in_the_unit_cube() {
        assertThrows(IllegalArgumentException.class, () -> new Correlithm(0.5, 1.5));
        assertThrows(IllegalArgumentException.class, () -> new Correlithm(Double.NaN));
        assertThrows(IllegalArgumentException.class, () -> new Correlithm());
    }

    @Test
    void points_from_different_spaces_have_no_distance() {
        assertThrows(IllegalArgumentException.class, () -> Correlithm.midpoint(3).distanceTo(Correlithm.midpoint(4)));
    }

    @Test
    void centroid_and_interpolation() {
        Correlithm a = new Correlithm(0, 0.5), b = new Correlithm(1, 0.5);
        assertArrayEquals(new double[] {0.5, 0.5}, Correlithm.centroid(List.of(a, b)).coordinates());
        assertArrayEquals(new double[] {0.25, 0.5}, a.interpolate(b, 0.25).coordinates());
        assertEquals(1, a.distanceTo(b));
        assertThrows(IllegalArgumentException.class, () -> a.interpolate(b, 1.5));
    }

    @Test
    void equality_is_exact_and_hash_consistent() {
        Correlithm x = Correlithm.random(new SeededPrng(3), 16), y = Correlithm.random(new SeededPrng(3), 16);
        assertEquals(x, y);
        assertEquals(x.hashCode(), y.hashCode());
        assertNotEquals(x, Correlithm.random(new SeededPrng(4), 16));
        assertEquals(new Correlithm(0.0), new Correlithm(-0.0));
        assertEquals(new Correlithm(0.0).hashCode(), new Correlithm(-0.0).hashCode());
    }
}
