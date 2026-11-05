package com.mindattic.corobs.seeding;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SeededPrngTest {

    @Test
    void same_seed_same_stream() {
        SeededPrng a = new SeededPrng(42), b = new SeededPrng(42);
        for (int i = 0; i < 1000; i++) assertEquals(a.nextUInt64(), b.nextUInt64());
    }

    @Test
    void different_seeds_differ() {
        SeededPrng a = new SeededPrng(1), b = new SeededPrng(2);
        boolean same = true;
        for (int i = 0; i < 16; i++) same &= a.nextUInt64() == b.nextUInt64();
        assertFalse(same);
    }

    @Test
    void doubles_are_uniform_on_the_unit_interval() {
        SeededPrng p = new SeededPrng(99);
        double sum = 0;
        for (int i = 0; i < 20000; i++) {
            double x = p.nextDouble();
            assertTrue(x >= 0 && x < 1);
            sum += x;
        }
        assertEquals(0.5, sum / 20000, 0.01);
    }

    @Test
    void derive_is_deterministic_and_independent_of_consumption() {
        SeededPrng a = new SeededPrng(5);
        a.nextUInt64();
        a.nextUInt64();
        SeededPrng b = new SeededPrng(5);
        assertEquals(a.derive("faction").seed(), b.derive("faction").seed());
        assertNotEquals(a.derive("faction").seed(), b.derive("turf").seed());
        assertNotEquals(a.seed(), a.derive("faction").seed());
    }

    @Test
    void next_needs_a_positive_bound() {
        assertThrows(IllegalArgumentException.class, () -> new SeededPrng(1).next(0));
    }
}
