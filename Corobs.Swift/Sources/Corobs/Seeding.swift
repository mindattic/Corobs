/// A deterministic pseudo-random stream (xoshiro256** seeded through SplitMix64). The same seed
/// yields the same doubles on every machine and every runtime, in every Corobs language. Everything
/// stochastic in Corobs draws from one of these, so a space can be rebuilt bit-for-bit from its seed.
public final class SeededPrng {
    private var s0: UInt64, s1: UInt64, s2: UInt64, s3: UInt64

    /// The root seed this stream (or `derive` chain) was built from.
    public let seed: Int64

    /// A fresh stream seeded from `seed`; the same seed always produces the same sequence.
    public init(_ seed: Int64) {
        self.seed = seed
        var x = UInt64(bitPattern: seed)
        let a = SeededPrng.splitMix(&x)
        let b = SeededPrng.splitMix(&x)
        let c = SeededPrng.splitMix(&x)
        let d = SeededPrng.splitMix(&x)
        (s0, s1, s2, s3) = (a, b, c, d)
    }

    /// A child stream named by `label`: the same parent seed and label always give the same child,
    /// independent of how many values the parent has produced. This is how a converter gets one fixed
    /// point per category value (`PRNG(seed, ply, value)`).
    public func derive(_ label: String) -> SeededPrng {
        SeededPrng(Int64(bitPattern: SeededPrng.fnv1a64(seed, label)))
    }

    /// The next raw 64-bit word of the xoshiro256** stream.
    public func nextUInt64() -> UInt64 {
        let result = SeededPrng.rotl(s1 &* 5, 7) &* 9
        let t = s1 &<< 17
        s2 ^= s0
        s3 ^= s1
        s1 ^= s2
        s0 ^= s3
        s2 ^= t
        s3 = SeededPrng.rotl(s3, 45)
        return result
    }

    /// Uniform on [0, 1): the top 53 bits of the next word, scaled by 2⁻⁵³.
    public func nextDouble() -> Double {
        Double(nextUInt64() >> 11) * 0x1.0p-53
    }

    /// Uniform integer on [0, `maxExclusive`), by truncating `nextDouble() * maxExclusive`.
    public func next(_ maxExclusive: Int) throws -> Int {
        guard maxExclusive > 0 else { throw CorobsError.argumentOutOfRange("maxExclusive must be positive.") }
        return Int(nextDouble() * Double(maxExclusive))
    }

    private static func rotl(_ x: UInt64, _ k: UInt64) -> UInt64 {
        (x &<< k) | (x &>> (64 &- k))
    }

    private static func splitMix(_ x: inout UInt64) -> UInt64 {
        x = x &+ 0x9E37_79B9_7F4A_7C15
        var z = x
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// FNV-1a over the seed's 8 little-endian bytes, then the label's UTF-8 bytes.
    private static func fnv1a64(_ seed: Int64, _ label: String) -> UInt64 {
        let prime: UInt64 = 1_099_511_628_211
        var h: UInt64 = 14_695_981_039_346_656_037
        let s = UInt64(bitPattern: seed)
        for i in 0..<8 {
            h ^= (s >> UInt64(8 * i)) & 0xFF
            h = h &* prime
        }
        for byte in label.utf8 {
            h ^= UInt64(byte)
            h = h &* prime
        }
        return h
    }
}
