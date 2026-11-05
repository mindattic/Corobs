package com.mindattic.corobs.converters;

import com.mindattic.corobs.geometry.Correlithm;
import com.mindattic.corobs.seeding.SeededPrng;
import com.mindattic.corobs.strings.StringCo;

/** A continuous variable on [min, max] mapped onto a line string CO, or onto a ring when the range wraps. */
public final class ContinuousConverter implements Converter<Double> {
    private final StringCo string;
    private final double min, max;
    private final boolean wraps;
    private final int dimensions;
    private final Correlithm missing;

    /** A non-wrapping converter over [min, max]. */
    public ContinuousConverter(SeededPrng prng, int dimensions, double min, double max) {
        this(prng, dimensions, min, max, false);
    }

    /** A converter over [min, max] on a fresh line, or a ring when {@code wraps}. */
    public ContinuousConverter(SeededPrng prng, int dimensions, double min, double max, boolean wraps) {
        if (!(max > min)) throw new IllegalArgumentException("max must exceed min.");
        string = wraps ? StringCo.ring(prng, dimensions) : StringCo.line(prng, dimensions);
        this.min = min; this.max = max; this.wraps = wraps;
        this.dimensions = dimensions;
        this.missing = Correlithm.midpoint(dimensions);
    }

    @Override public int dimensions() { return dimensions; }
    @Override public Correlithm missing() { return missing; }

    /** The value's point ({@link #missing()} for {@code null}, NaN, or an infinite value on a ring). */
    @Override
    public Correlithm convert(Double value) {
        if (value == null || Double.isNaN(value)) return missing;
        // COR-T5 (docs/BUGS.md, a decision): a ring has no phase for infinity.
        if (wraps && Double.isInfinite(value)) return missing;
        double t = (value - min) / (max - min);
        return string.at(t);
    }
}
