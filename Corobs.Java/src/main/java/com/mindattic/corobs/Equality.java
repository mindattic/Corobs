package com.mindattic.corobs;

import java.util.Objects;

/** Equality for ids, the analogue of .NET's {@code IEqualityComparer}: {@link #hash} must agree with {@link #equal}. */
public interface Equality<T> {

    /** Whether {@code a} and {@code b} are the same id. */
    boolean equal(T a, T b);

    /** A hash consistent with {@link #equal}. */
    int hash(T value);

    /** {@link Object#equals} and {@link Object#hashCode}. */
    static <T> Equality<T> natural() {
        return new Equality<>() {
            @Override public boolean equal(T a, T b) { return Objects.equals(a, b); }
            @Override public int hash(T value) { return Objects.hashCode(value); }
        };
    }

    /** A value wrapped so that hash-based collections compare it under {@code equality}. */
    record Key<T>(T value, Equality<? super T> equality) {
        @Override
        @SuppressWarnings("unchecked")
        public boolean equals(Object o) {
            return o instanceof Key<?> k && equality.equal(value, (T) k.value);
        }

        @Override
        public int hashCode() { return equality.hash(value); }
    }
}
