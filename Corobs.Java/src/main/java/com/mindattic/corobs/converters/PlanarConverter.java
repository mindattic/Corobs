package com.mindattic.corobs.converters;

import com.mindattic.corobs.geometry.Correlithm;
import com.mindattic.corobs.seeding.SeededPrng;
import com.mindattic.corobs.strings.StringCo;

/** A point in a bounded plane (a map position) on a planar string CO (Fig. VII-10). */
public final class PlanarConverter implements Converter<PlanarConverter.Position> {

    /** A position in the plane. */
    public record Position(double x, double y) {}

    private final StringCo plane;
    private final double minX, maxX, minY, maxY;
    private final int dimensions;
    private final Correlithm missing;

    /** A planar converter over [minX, maxX] × [minY, maxY]. */
    public PlanarConverter(SeededPrng prng, int dimensions, double minX, double maxX, double minY, double maxY) {
        if (!(maxX > minX) || !(maxY > minY)) throw new IllegalArgumentException("Each axis needs max > min.");
        plane = StringCo.plane(prng, dimensions);
        this.minX = minX; this.maxX = maxX; this.minY = minY; this.maxY = maxY;
        this.dimensions = dimensions;
        this.missing = Correlithm.midpoint(dimensions);
    }

    @Override public int dimensions() { return dimensions; }
    @Override public Correlithm missing() { return missing; }

    /** The value's point ({@link #missing()} for {@code null} or a NaN coordinate). */
    @Override
    public Correlithm convert(Position value) {
        if (value == null) return missing;
        double x = value.x(), y = value.y();
        if (Double.isNaN(x) || Double.isNaN(y)) return missing;
        return plane.at((x - minX) / (maxX - minX), (y - minY) / (maxY - minY));
    }
}
