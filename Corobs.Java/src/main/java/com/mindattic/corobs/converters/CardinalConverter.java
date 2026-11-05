package com.mindattic.corobs.converters;

import com.mindattic.corobs.geometry.Correlithm;
import com.mindattic.corobs.seeding.SeededPrng;

import java.util.HashMap;
import java.util.Map;
import java.util.Objects;
import java.util.function.Function;

/** A cardinal set (values with no order): each distinct value gets its own random CO, derived from the seed and
 *  the value's key, so the mapping does not depend on the order values were first seen. */
public final class CardinalConverter<T> implements Converter<T> {
    private final SeededPrng root;
    private final Function<? super T, String> key;
    private final Map<String, Correlithm> cache = new HashMap<>();
    private final int dimensions;
    private final Correlithm missing;

    /** Keys are {@code String.valueOf(value)}. */
    public CardinalConverter(SeededPrng root, int dimensions) { this(root, dimensions, null); }

    /** Keys come from {@code key}, or {@code String.valueOf(value)} when null. */
    public CardinalConverter(SeededPrng root, int dimensions, Function<? super T, String> key) {
        this.root = root;
        this.key = key != null ? key : v -> Objects.toString(v, "");
        this.dimensions = dimensions;
        this.missing = Correlithm.midpoint(dimensions);
    }

    @Override public int dimensions() { return dimensions; }
    @Override public Correlithm missing() { return missing; }

    /** The value's CO (created and cached on first use), or {@link #missing()} for {@code null}. */
    @Override
    public Correlithm convert(T value) {
        if (value == null) return missing;
        String k = key.apply(value);
        Correlithm co = cache.get(k);
        if (co == null) {
            co = Correlithm.random(root.derive(k), dimensions);
            cache.put(k, co);
        }
        return co;
    }
}
