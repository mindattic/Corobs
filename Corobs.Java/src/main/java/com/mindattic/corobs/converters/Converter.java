package com.mindattic.corobs.converters;

import com.mindattic.corobs.geometry.Correlithm;

/** Moves world data into CO space (a <i>sensor</i>, Ch. IX). A missing value ({@code null}) lands on the
 *  cube's midpoint, which carries no bits. */
public interface Converter<T> {

    /** N: the dimensionality of the points this converter produces. */
    int dimensions();

    /** The point for a value, or {@link #missing()} for {@code null}. */
    Correlithm convert(T value);

    /** Where an absent value lands: {@link Correlithm#midpoint}. */
    Correlithm missing();
}
