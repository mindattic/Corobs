#if canImport(Darwin)
import Darwin
#elseif canImport(ucrt)
import ucrt
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

/// A string CO (Ch. VII): a lower-dimensional geometry (a line, a ring, a plane) embedded in the
/// N-cube so that distance along the geometry is reflected as distance in the cube, rising from zero
/// to standard distance as positions move apart, while every position stays at standard distance from
/// any unrelated random point.
///
/// Construction follows the book's advice to "distribute the anomalies randomly": each dimension
/// carries two random values and switches between them at its own random breakpoint along the
/// geometry. No interpolation is involved, so no position "takes a shortcut" toward third points.
public final class StringCo {
    private enum Kind { case line, ring, plane }

    private let kind: Kind
    private let a: [Double], b: [Double], o: [Double]
    private let dx: [Double], dy: [Double]

    /// N: the dimensionality of the cube this geometry is embedded in.
    public var dimensions: Int { a.count }

    private init(_ kind: Kind, _ a: [Double], _ b: [Double], _ o: [Double], _ dx: [Double] = [], _ dy: [Double] = []) {
        (self.kind, self.a, self.b, self.o, self.dx, self.dy) = (kind, a, b, o, dx, dy)
    }

    /// A line segment parameterised by t ∈ [0, 1]. Distance between t and t′ ≈ μ·√|t − t′|.
    public static func line(_ prng: SeededPrng, dimensions: Int) throws -> StringCo {
        let (a, b) = try values(prng, dimensions)
        var o = [Double](repeating: 0, count: dimensions)
        for i in o.indices { o[i] = prng.nextDouble() }
        return StringCo(.line, a, b, o)
    }

    /// A closed ring parameterised by t ∈ [0, 1) with 0 ≡ 1, for hours, headings, seasons.
    /// Distance between t and t′ ≈ μ·√(2Δ) where Δ is the circular gap (≤ ½).
    public static func ring(_ prng: SeededPrng, dimensions: Int) throws -> StringCo {
        let (a, b) = try values(prng, dimensions)
        var o = [Double](repeating: 0, count: dimensions)
        for i in o.indices { o[i] = prng.nextDouble() }
        return StringCo(.ring, a, b, o)
    }

    /// A unit square parameterised by (x, y) ∈ [0, 1]². Each dimension watches a random direction, so
    /// distance grows with planar separation in every direction alike: the symmetric "cone" of
    /// Fig. VII-10, without the troughs of concatenated 1-D strings (Fig. VII-11).
    public static func plane(_ prng: SeededPrng, dimensions: Int) throws -> StringCo {
        let (a, b) = try values(prng, dimensions)
        var o = [Double](repeating: 0, count: dimensions)
        var dx = [Double](repeating: 0, count: dimensions)
        var dy = [Double](repeating: 0, count: dimensions)
        for i in 0..<dimensions {
            let theta = prng.nextDouble() * 2 * Double.pi
            dx[i] = cos(theta)
            dy[i] = sin(theta)
            let lo = dotnetMin(0, dx[i]) + dotnetMin(0, dy[i])
            let hi = dotnetMax(0, dx[i]) + dotnetMax(0, dy[i])
            let span = prng.nextDouble() * (hi - lo)
            o[i] = lo + span
        }
        return StringCo(.plane, a, b, o, dx, dy)
    }

    /// The point at position t on a line (clamped to [0, 1]) or a ring (taken mod 1).
    public func at(_ t: Double) throws -> Correlithm {
        if kind == .plane { throw CorobsError.invalidOperation("A planar string CO takes two coordinates.") }
        if t.isNaN { throw CorobsError.argumentOutOfRange("t must be a number.") }
        var c = [Double](repeating: 0, count: dimensions)
        if kind == .line {
            let t = dotnetClamp(t, 0, 1)
            for i in c.indices { c[i] = t < o[i] ? a[i] : b[i] }
        } else {
            // A ring has no phase at infinity (the reference's COR-T4 fix, docs/BUGS.md).
            if t.isInfinite { throw CorobsError.argumentOutOfRange("A ring has no position at infinity.") }
            for i in c.indices {
                var phase = t - o[i]
                phase -= phase.rounded(.down)
                c[i] = phase < 0.5 ? a[i] : b[i]
            }
        }
        return try Correlithm(c)
    }

    /// The point at (x, y) on a plane, each clamped to [0, 1].
    public func at(x: Double, y: Double) throws -> Correlithm {
        if kind != .plane { throw CorobsError.invalidOperation("Only a planar string CO takes two coordinates.") }
        if x.isNaN || y.isNaN { throw CorobsError.argumentOutOfRange("x and y must be numbers.") }
        let x = dotnetClamp(x, 0, 1)
        let y = dotnetClamp(y, 0, 1)
        var c = [Double](repeating: 0, count: dimensions)
        for i in c.indices {
            let px = x * dx[i]
            let py = y * dy[i]
            let p = px + py
            c[i] = p < o[i] ? a[i] : b[i]
        }
        return try Correlithm(c)
    }

    /// The `index`-th of `count` evenly spaced positions: an ordinal set such as an alphabet, a rank
    /// or a tier (Fig. VII-8).
    public func atIndex(_ index: Int, count: Int) throws -> Correlithm {
        if count <= 0 { throw CorobsError.argumentOutOfRange("count must be positive.") }
        if index < 0 || index >= count { throw CorobsError.argumentOutOfRange("index must lie in [0, count).") }
        if kind == .ring { return try at(Double(index) / Double(count)) }
        return try at(count == 1 ? 0 : Double(index) / Double(count - 1))
    }

    private static func values(_ prng: SeededPrng, _ dimensions: Int) throws -> ([Double], [Double]) {
        guard dimensions > 0 else { throw CorobsError.argumentOutOfRange("dimensions must be positive.") }
        var a = [Double](repeating: 0, count: dimensions)
        var b = [Double](repeating: 0, count: dimensions)
        for i in 0..<dimensions {
            a[i] = prng.nextDouble()
            b[i] = prng.nextDouble()
        }
        return (a, b)
    }
}

// .NET's Math.Min/Max/Clamp, exactly: NaN propagates and −0 is less than +0. Swift's min/max differ
// on signed zeros, which can move a plane breakpoint by the sign of a zero.
private func dotnetMin(_ x: Double, _ y: Double) -> Double {
    if x != y { return x.isNaN ? x : (x < y ? x : y) }
    return y.sign == .minus ? y : x
}

private func dotnetMax(_ x: Double, _ y: Double) -> Double {
    if x != y { return x.isNaN ? x : (y < x ? x : y) }
    return y.sign == .minus ? x : y
}

private func dotnetClamp(_ value: Double, _ lo: Double, _ hi: Double) -> Double {
    if value < lo { return lo }
    if value > hi { return hi }
    return value
}
