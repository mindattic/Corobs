package com.mindattic.corobs.converters;

import com.mindattic.corobs.Equality;
import com.mindattic.corobs.geometry.Correlithm;
import com.mindattic.corobs.seeding.SeededPrng;
import com.mindattic.corobs.strings.StringCo;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/** An ordinal set (an order but no scale): evenly spaced positions on a line string CO (Fig. VII-8). An unknown
 *  value is an error, not a guess. */
public final class OrdinalConverter<T> implements Converter<T> {
    private final Map<Equality.Key<T>, Integer> index = new HashMap<>();
    private final Equality<? super T> equality;
    private final StringCo line;
    private final int dimensions;
    private final Correlithm missing;

    /** Values compared with {@link Object#equals}. */
    public OrdinalConverter(SeededPrng prng, int dimensions, List<T> order) { this(prng, dimensions, order, null); }

    /** Values compared with {@code equality} ({@link Object#equals} when null). */
    public OrdinalConverter(SeededPrng prng, int dimensions, List<T> order, Equality<? super T> equality) {
        if (order.isEmpty()) throw new IllegalArgumentException("An ordinal set needs at least one value.");
        this.equality = equality != null ? equality : Equality.natural();
        for (int i = 0; i < order.size(); i++)
            if (index.putIfAbsent(new Equality.Key<>(order.get(i), this.equality), i) != null)
                throw new IllegalArgumentException("'" + order.get(i) + "' appears twice in the order.");
        line = StringCo.line(prng, dimensions);
        this.dimensions = dimensions;
        this.missing = Correlithm.midpoint(dimensions);
    }

    @Override public int dimensions() { return dimensions; }
    @Override public Correlithm missing() { return missing; }

    /** How many distinct values are in the order. */
    public int count() { return index.size(); }

    /** The value's position on the line ({@link #missing()} for {@code null}); throws for a value outside the set. */
    @Override
    public Correlithm convert(T value) {
        if (value == null) return missing;
        Integer i = index.get(new Equality.Key<>(value, equality));
        if (i == null) throw new IllegalArgumentException("'" + value + "' is not in this ordinal set.");
        return line.atIndex(i, index.size());
    }
}
