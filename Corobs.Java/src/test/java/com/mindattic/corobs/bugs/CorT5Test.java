package com.mindattic.corobs.bugs;

import com.mindattic.corobs.converters.ContinuousConverter;
import com.mindattic.corobs.seeding.SeededPrng;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import static org.junit.jupiter.api.Assertions.assertEquals;

/** COR-T5 is a decision, not a proven error (docs/BUGS.md): this pins the chosen behaviour. */
class CorT5Test {

    @ParameterizedTest
    @ValueSource(doubles = {Double.POSITIVE_INFINITY, Double.NEGATIVE_INFINITY})
    void decision_a_wrapping_converter_maps_infinity_to_missing(double value) {
        ContinuousConverter hours = new ContinuousConverter(new SeededPrng(1), 32, 0, 24, true);
        assertEquals(hours.missing(), hours.convert(value));
    }
}
