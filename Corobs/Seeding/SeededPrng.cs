using System.Text;

namespace Corobs.Seeding;

/// <summary>
/// A deterministic pseudo-random stream (xoshiro256** seeded through SplitMix64). The same seed
/// yields the same doubles on every machine and every runtime version — unlike <c>System.Random</c>,
/// whose algorithm is not a contract. Everything stochastic in COROBS draws from one of these, so a
/// space can be rebuilt bit-for-bit from its seed.
/// </summary>
public sealed class SeededPrng
{
    private ulong _s0, _s1, _s2, _s3;

    /// <summary>The root seed this stream (or <see cref="Derive"/> chain) was built from.</summary>
    public long Seed { get; }

    /// <summary>A fresh stream seeded from <paramref name="seed"/>; the same seed always produces the
    /// same sequence of <see cref="NextUInt64"/>/<see cref="NextDouble"/>/<see cref="Next"/> calls.</summary>
    public SeededPrng(long seed)
    {
        Seed = seed;
        var x = unchecked((ulong)seed);
        _s0 = SplitMix(ref x);
        _s1 = SplitMix(ref x);
        _s2 = SplitMix(ref x);
        _s3 = SplitMix(ref x);
    }

    /// <summary>A child stream named by <paramref name="label"/>: the same parent seed and label
    /// always give the same child, independent of how many values the parent has produced. This is
    /// how a converter gets one fixed point per category value (<c>PRNG(seed, ply, value)</c>).</summary>
    public SeededPrng Derive(string label) => new(unchecked((long)Fnv1a64(Seed, label)));

    /// <summary>The next raw 64-bit word of the xoshiro256** stream; <see cref="NextDouble"/> and
    /// <see cref="Next"/> are built on this.</summary>
    public ulong NextUInt64()
    {
        var result = RotL(_s1 * 5, 7) * 9;
        var t = _s1 << 17;
        _s2 ^= _s0;
        _s3 ^= _s1;
        _s1 ^= _s2;
        _s0 ^= _s3;
        _s2 ^= t;
        _s3 = RotL(_s3, 45);
        return result;
    }

    /// <summary>Uniform on [0, 1).</summary>
    public double NextDouble() => (NextUInt64() >> 11) * (1.0 / (1UL << 53));

    /// <summary>Uniform integer on [0, <paramref name="maxExclusive"/>).</summary>
    public int Next(int maxExclusive)
    {
        if (maxExclusive <= 0) throw new ArgumentOutOfRangeException(nameof(maxExclusive));
        return (int)(NextDouble() * maxExclusive);
    }

    private static ulong RotL(ulong x, int k) => (x << k) | (x >> (64 - k));

    private static ulong SplitMix(ref ulong x)
    {
        x += 0x9E3779B97F4A7C15UL;
        var z = x;
        z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9UL;
        z = (z ^ (z >> 27)) * 0x94D049BB133111EBUL;
        return z ^ (z >> 31);
    }

    private static ulong Fnv1a64(long seed, string label)
    {
        var h = 14695981039346656037UL;
        var s = unchecked((ulong)seed);
        for (var i = 0; i < 8; i++)
        {
            h ^= (byte)(s >> (8 * i));
            h *= 1099511628211UL;
        }
        foreach (var b in Encoding.UTF8.GetBytes(label))
        {
            h ^= b;
            h *= 1099511628211UL;
        }
        return h;
    }
}
