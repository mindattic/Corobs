#if canImport(Darwin)
import Darwin
#elseif canImport(ucrt)
import ucrt
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

/// The statistics of the real unit N-cube (Lawrence, *Correlithm Object Technology*, Ch. II–III).
/// Two points chosen at random are almost always `standardDistance` apart, with a standard
/// deviation that does not grow with N (Table II-1). Proximity far below that distance is therefore
/// information: `bitContent` says how much (Eq. III-H), `probabilityOfProximity` how unlikely by
/// chance (Eq. III-J), `pointCapacity` how many random points fit before two collide (Eq. III-Q).
/// Valid for N of about 20 and up; 50–128 is the working range.
public enum NCube {
    /// σ of the distance between two random points: √(7/120) ≈ 0.2415, independent of N.
    public static let standardDeviation = 0.24152294576982397

    /// σ of the distance from the midpoint to a random point: √(1/60) ≈ 0.1291.
    public static let radiusDeviation = 0.12909944487358055

    /// σ of the distance from a corner to a random point: √(1/15) ≈ 0.2582.
    public static let diameterDeviation = 0.2581988897471611

    /// μ: expected distance between two random points, √(N/6).
    public static func standardDistance(_ dimensions: Int) throws -> Double {
        (Double(try check(dimensions)) / 6.0).squareRoot()
    }

    /// Expected distance from the midpoint to a random point, √(N/12).
    public static func standardRadius(_ dimensions: Int) throws -> Double {
        (Double(try check(dimensions)) / 12.0).squareRoot()
    }

    /// Expected distance from a corner to a random point, √(N/3).
    public static func standardDiameter(_ dimensions: Int) throws -> Double {
        (Double(try check(dimensions)) / 3.0).squareRoot()
    }

    /// Expected distance between two random corners, √(N/2).
    public static func cornerDistance(_ dimensions: Int) throws -> Double {
        (Double(try check(dimensions)) / 2.0).squareRoot()
    }

    /// Midpoint to any corner, exactly √(N/4).
    public static func halfDiagonal(_ dimensions: Int) throws -> Double {
        (Double(try check(dimensions)) / 4.0).squareRoot()
    }

    /// Opposite corners, exactly √N.
    public static func majorDiagonal(_ dimensions: Int) throws -> Double {
        Double(try check(dimensions)).squareRoot()
    }

    /// How many standard deviations below μ a distance lies (negative when beyond μ).
    public static func deviationsBelow(_ dimensions: Int, _ distance: Double) throws -> Double {
        (try standardDistance(dimensions) - distance) / standardDeviation
    }

    /// The distance that lies `deviations` σ below μ.
    public static func distanceAtDeviations(_ dimensions: Int, _ deviations: Double) throws -> Double {
        let offset = deviations * standardDeviation
        return try standardDistance(dimensions) - offset
    }

    /// Eq. III-H: bits of information in two points lying `distance` apart,
    /// ((μ − d)/σ)² / ln 2 ≈ 24.75·(μ − d)². Zero at or beyond standard distance.
    public static func bitContent(_ dimensions: Int, _ distance: Double) throws -> Double {
        let x = try deviationsBelow(dimensions, distance)
        return x <= 0 ? 0 : x * x / log(2.0)
    }

    /// The distance at which proximity is worth `bits` bits.
    public static func distanceForBits(_ dimensions: Int, _ bits: Double) throws -> Double {
        if bits < 0 { throw CorobsError.argumentOutOfRange("bits must not be negative.") }
        let offset = standardDeviation * (bits * log(2.0)).squareRoot()
        return try standardDistance(dimensions) - offset
    }

    /// Eq. III-J: the probability that two random points lie closer than `distance`,
    /// 10^(−7.45(μ − d)²) = 2^(−bits). One at or beyond μ.
    public static func probabilityOfProximity(_ dimensions: Int, _ distance: Double) throws -> Double {
        pow(2.0, -(try bitContent(dimensions, distance)))
    }

    /// Eq. III-Q: how many random points can be placed before two are expected to lie closer than
    /// `distance`, 10^(3.7(μ − d)²).
    public static func pointCapacity(_ dimensions: Int, _ distance: Double) throws -> Double {
        let gap = try standardDistance(dimensions) - distance
        return gap <= 0 ? 1 : pow(10.0, 3.7 * gap * gap)
    }

    private static func check(_ dimensions: Int) throws -> Int {
        guard dimensions > 0 else {
            throw CorobsError.argumentOutOfRange("A space needs at least one dimension; the statistics hold from about 20.")
        }
        return dimensions
    }
}

/// A correlithm object: one point in the real unit N-cube, every coordinate in [0, 1]. A CO is a
/// *soft token* (Ch. IV): it stands for its datum exactly at its coordinates and, to a degree
/// `NCube.bitContent` quantifies, at every point nearby. Immutable.
public struct Correlithm: Hashable, Sendable, CustomStringConvertible {
    /// All N coordinates, in order.
    public let coordinates: [Double]

    /// N: the dimensionality of the cube this point lives in.
    public var dimensions: Int { coordinates.count }

    /// The coordinate on one dimension, in [0, 1].
    public subscript(dimension: Int) -> Double { coordinates[dimension] }

    /// A point at exactly these coordinates; each must lie in [0, 1].
    public init(_ coordinates: [Double]) throws {
        if coordinates.isEmpty { throw CorobsError.argument("A point needs at least one coordinate.") }
        for v in coordinates where v.isNaN || v < 0 || v > 1 {
            throw CorobsError.argumentOutOfRange("Every coordinate must lie in [0, 1].")
        }
        self.coordinates = coordinates
    }

    init(owned coordinates: [Double]) {
        self.coordinates = coordinates
    }

    /// A point chosen uniformly at random from the whole cube: a fresh token, at standard distance
    /// from every other random token with overwhelming probability.
    public static func random(_ prng: SeededPrng, dimensions: Int) throws -> Correlithm {
        var c = [Double](repeating: 0, count: try checkDimensions(dimensions))
        for i in c.indices { c[i] = prng.nextDouble() }
        return Correlithm(owned: c)
    }

    /// The cube's centre, 0.5 in every dimension: where a missing value goes, because the midpoint is
    /// at `NCube.standardRadius` from everything and carries no bits.
    public static func midpoint(_ dimensions: Int) throws -> Correlithm {
        Correlithm(owned: [Double](repeating: 0.5, count: try checkDimensions(dimensions)))
    }

    /// Euclidean distance squared to `other`, from the same cube. Summed left to right.
    public func squaredDistance(to other: Correlithm) throws -> Double {
        try checkSame(other)
        var s = 0.0
        for i in coordinates.indices {
            let d = coordinates[i] - other.coordinates[i]
            let sq = d * d
            s += sq
        }
        return s
    }

    /// Euclidean distance to `other`; compare against `NCube.standardDistance` to read it as
    /// information (`NCube.bitContent`).
    public func distance(to other: Correlithm) throws -> Double {
        try squaredDistance(to: other).squareRoot()
    }

    /// Linear interpolation by `fraction` from this point toward `other`. Note Ch. VII's warning:
    /// interpolated points "take a shortcut" and sit closer than standard distance to third points;
    /// use `StringCo` for sequences.
    public func interpolate(toward other: Correlithm, fraction: Double) throws -> Correlithm {
        try checkSame(other)
        if fraction < 0 || fraction > 1 { throw CorobsError.argumentOutOfRange("fraction must lie in [0, 1].") }
        var c = [Double](repeating: 0, count: coordinates.count)
        for i in c.indices {
            let step = (other.coordinates[i] - coordinates[i]) * fraction
            c[i] = coordinates[i] + step
        }
        return Correlithm(owned: c)
    }

    /// The coordinate-wise mean of a set of points.
    public static func centroid(_ points: [Correlithm]) throws -> Correlithm {
        guard let first = points.first else { throw CorobsError.argument("A centroid needs at least one point.") }
        var sum = [Double](repeating: 0, count: first.dimensions)
        for p in points {
            if p.dimensions != sum.count { throw CorobsError.argument("All points must share one dimensionality.") }
            for i in sum.indices { sum[i] += p.coordinates[i] }
        }
        let count = Double(points.count)
        for i in sum.indices { sum[i] /= count }
        return Correlithm(owned: sum)
    }

    /// A point that superposes several: their centroid. Each component remains recoverable
    /// (Ch. VIII, Superposition).
    public static func superpose(_ points: [Correlithm]) throws -> Correlithm {
        try centroid(points)
    }

    /// Just the dimensionality; coordinates are not meant to be read as text.
    public var description: String { "CO[\(dimensions)]" }

    private func checkSame(_ other: Correlithm) throws {
        if other.coordinates.count != coordinates.count {
            throw CorobsError.argument("Points from different spaces have no distance.")
        }
    }

    private static func checkDimensions(_ dimensions: Int) throws -> Int {
        guard dimensions > 0 else { throw CorobsError.argumentOutOfRange("dimensions must be positive.") }
        return dimensions
    }
}
