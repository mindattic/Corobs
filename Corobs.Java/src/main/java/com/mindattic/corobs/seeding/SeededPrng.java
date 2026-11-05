package com.mindattic.corobs.seeding;

import java.nio.charset.StandardCharsets;

/**
 * A deterministic pseudo-random stream (xoshiro256** seeded through SplitMix64). The same seed yields the
 * same doubles on every machine and in every language port; everything stochastic in COROBS draws from
 * one of these, so a space can be rebuilt bit-for-bit from its seed.
 */
public final class SeededPrng {
    private long s0, s1, s2, s3;
    private final long seed;

    /** A fresh stream seeded from {@code seed}. */
    public SeededPrng(long seed) {
        this.seed = seed;
        long[] x = {seed};
        s0 = splitMix(x);
        s1 = splitMix(x);
        s2 = splitMix(x);
        s3 = splitMix(x);
    }

    /** The root seed this stream (or {@link #derive} chain) was built from. */
    public long seed() { return seed; }

    /** A child stream named by {@code label}: the same parent seed and label always give the same child,
     *  independent of how many values the parent has produced. */
    public SeededPrng derive(String label) { return new SeededPrng(fnv1a64(seed, label)); }

    /** The next raw 64-bit word of the xoshiro256** stream, as unsigned bits in a {@code long}. */
    public long nextUInt64() {
        long result = Long.rotateLeft(s1 * 5, 7) * 9;
        long t = s1 << 17;
        s2 ^= s0;
        s3 ^= s1;
        s1 ^= s2;
        s0 ^= s3;
        s2 ^= t;
        s3 = Long.rotateLeft(s3, 45);
        return result;
    }

    /** Uniform on [0, 1). */
    public double nextDouble() { return (nextUInt64() >>> 11) * (1.0 / (1L << 53)); }

    /** Uniform integer on [0, {@code maxExclusive}). */
    public int next(int maxExclusive) {
        if (maxExclusive <= 0) throw new IllegalArgumentException("maxExclusive must be positive");
        return (int) (nextDouble() * maxExclusive);
    }

    private static long splitMix(long[] x) {
        x[0] += 0x9E3779B97F4A7C15L;
        long z = x[0];
        z = (z ^ (z >>> 30)) * 0xBF58476D1CE4E5B9L;
        z = (z ^ (z >>> 27)) * 0x94D049BB133111EBL;
        return z ^ (z >>> 31);
    }

    private static long fnv1a64(long seed, String label) {
        long h = 0xCBF29CE484222325L;
        for (int i = 0; i < 8; i++) {
            h ^= (seed >>> (8 * i)) & 0xFF;
            h *= 0x100000001B3L;
        }
        for (byte b : label.getBytes(StandardCharsets.UTF_8)) {
            h ^= b & 0xFF;
            h *= 0x100000001B3L;
        }
        return h;
    }
}
