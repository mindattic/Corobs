package com.mindattic.corobs.converters;

import com.mindattic.corobs.geometry.Correlithm;
import com.mindattic.corobs.geometry.NCube;
import com.mindattic.corobs.seeding.SeededPrng;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class ConverterTest {
    private static final int N = 128;

    @Test
    void cardinal_values_are_fixed_tokens_at_standard_distance_from_each_other() {
        CardinalConverter<String> c = new CardinalConverter<>(new SeededPrng(1), N);
        CardinalConverter<String> again = new CardinalConverter<>(new SeededPrng(1), N);
        Correlithm first = c.convert("Underclan");
        assertSame(first, c.convert("Underclan"), "a value is one token, cached");
        assertEquals(first, again.convert("Underclan"), "same seed, same token, whatever was seen first");
        double mu = NCube.standardDistance(N);
        assertEquals(1, c.convert("Underclan").distanceTo(c.convert("Arcturus")) / mu, 0.2);
        assertEquals(Correlithm.midpoint(N), c.convert(null));
    }

    @Test
    void ordinal_neighbours_are_closer_than_extremes_and_unknowns_throw() {
        OrdinalConverter<String> c = new OrdinalConverter<>(new SeededPrng(2), N, List.of("street", "runner", "fixer", "corpo", "board"));
        assertTrue(c.convert("street").distanceTo(c.convert("runner")) < c.convert("street").distanceTo(c.convert("board")));
        assertThrows(IllegalArgumentException.class, () -> c.convert("god"));
        assertEquals(c.missing(), c.convert(null));
        assertEquals(5, c.count());
    }

    @Test
    void continuous_values_interpolate_and_can_wrap() {
        ContinuousConverter years = new ContinuousConverter(new SeededPrng(3), N, 2200, 2300);
        assertTrue(years.convert(2230.0).distanceTo(years.convert(2231.0)) < years.convert(2230.0).distanceTo(years.convert(2290.0)));
        assertEquals(years.missing(), years.convert(null));
        assertEquals(years.missing(), years.convert(Double.NaN));

        ContinuousConverter hours = new ContinuousConverter(new SeededPrng(4), N, 0, 24, true);
        assertTrue(hours.convert(23.5).distanceTo(hours.convert(0.5)) < hours.convert(23.5).distanceTo(hours.convert(12.0)));
    }

    @Test
    void planar_positions_are_near_when_the_map_says_so() {
        PlanarConverter map = new PlanarConverter(new SeededPrng(5), N, -10, 10, -10, 10);
        Correlithm here = map.convert(new PlanarConverter.Position(0, 0));
        assertTrue(here.distanceTo(map.convert(new PlanarConverter.Position(0.5, 0.5)))
                < here.distanceTo(map.convert(new PlanarConverter.Position(8, -7))));
        assertEquals(map.missing(), map.convert(null));
    }

    @Test
    void bad_ranges_throw() {
        assertThrows(IllegalArgumentException.class, () -> new ContinuousConverter(new SeededPrng(1), 8, 1, 1));
        assertThrows(IllegalArgumentException.class, () -> new PlanarConverter(new SeededPrng(1), 8, 0, 1, 2, 2));
        assertThrows(IllegalArgumentException.class, () -> new OrdinalConverter<String>(new SeededPrng(1), 8, List.of()));
    }
}
