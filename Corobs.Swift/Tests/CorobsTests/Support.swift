import Corobs
import Foundation

/// The Corobs.Swift package directory, found from this file's own path.
let packageDirectory: URL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()   // CorobsTests
    .deletingLastPathComponent()   // Tests
    .deletingLastPathComponent()   // Corobs.Swift

func near(_ actual: Double, _ expected: Double, within tolerance: Double) -> Bool {
    abs(actual - expected) <= tolerance
}

func mean(_ xs: [Double]) -> Double {
    xs.reduce(0, +) / Double(xs.count)
}

func clamp(_ v: Double, _ lo: Double, _ hi: Double) -> Double {
    v < lo ? lo : (v > hi ? hi : v)
}

/// The reference's test helper: a point within `jitter` of `centre` on every axis, clamped to the cube.
func nearPoint(_ centre: Correlithm, _ prng: SeededPrng, _ jitter: Double) throws -> Correlithm {
    var c = [Double](repeating: 0, count: centre.dimensions)
    for i in c.indices { c[i] = clamp(centre[i] + (prng.nextDouble() - 0.5) * 2 * jitter, 0, 1) }
    return try Correlithm(c)
}

/// A predictor that knows every true pair, under the caller's key.
func oracle<T, K: Hashable>(_ pairs: [(T, T)], key: @escaping (T) -> K) -> (T) -> [T] {
    var map: [K: [T]] = [:]
    for (a, b) in pairs {
        map[key(a), default: []].append(b)
        map[key(b), default: []].append(a)
    }
    return { map[key($0)] ?? [] }
}
