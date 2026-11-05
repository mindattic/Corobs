/// Moves world data into CO space (a *sensor*, Ch. IX). Every converter answers the same question for
/// a missing value: the cube's midpoint, which carries no bits.
public protocol Converter {
    /// The kind of world value this converter reads.
    associatedtype Value

    /// N: the dimensionality of the points this converter produces.
    var dimensions: Int { get }

    /// Where an absent value lands: `Correlithm.midpoint`.
    var missing: Correlithm { get }

    /// The point for a value, or `missing` for `nil`.
    func convert(_ value: Value?) throws -> Correlithm
}

/// A cardinal set: values with no order (a faction, a species, a type). Each distinct value gets its
/// own random CO, derived from the seed and the value's key, so the mapping is the same on every build
/// regardless of the order values were first seen.
public final class CardinalConverter<T>: Converter {
    public typealias Value = T

    private let root: SeededPrng
    private let key: (T) -> String
    private var cache: [String: Correlithm] = [:]

    public let dimensions: Int
    public let missing: Correlithm

    /// A cardinal converter over `dimensions`-dimensional points, each value's random CO derived from
    /// `root` and the value's key (`key`, or its `description` when omitted).
    public init(_ root: SeededPrng, dimensions: Int, key: ((T) -> String)? = nil) throws {
        self.root = root
        self.key = key ?? { String(describing: $0) }
        self.dimensions = dimensions
        self.missing = try Correlithm.midpoint(dimensions)
    }

    /// The value's CO (created and cached on first use), or `missing` for `nil`.
    public func convert(_ value: T?) throws -> Correlithm {
        guard let value else { return missing }
        let k = key(value)
        if let co = cache[k] { return co }
        let co = try Correlithm.random(root.derive(k), dimensions: dimensions)
        cache[k] = co
        return co
    }
}

/// An ordinal set: values with an order but no scale (tiers, ranks, an alphabet). Evenly spaced
/// positions on a line string CO, so neighbours are near and the extremes are at standard distance
/// (Fig. VII-8). An unknown value is an error, not a guess.
public final class OrdinalConverter<T: Hashable>: Converter {
    public typealias Value = T

    private let index: [T: Int]
    private let line: StringCo

    public let dimensions: Int
    public let missing: Correlithm

    /// How many distinct values are in the order.
    public var count: Int { index.count }

    /// An ordinal converter whose first `order` value is the first position, up to the last, evenly
    /// spaced along a fresh line string CO over `dimensions` dimensions.
    public init(_ prng: SeededPrng, dimensions: Int, order: [T]) throws {
        if order.isEmpty { throw CorobsError.argument("An ordinal set needs at least one value.") }
        var index: [T: Int] = [:]
        for (i, v) in order.enumerated() {
            if index[v] != nil { throw CorobsError.argument("'\(v)' appears twice in the order.") }
            index[v] = i
        }
        self.index = index
        self.line = try StringCo.line(prng, dimensions: dimensions)
        self.dimensions = dimensions
        self.missing = try Correlithm.midpoint(dimensions)
    }

    /// The value's position on the line (`missing` for `nil`); throws for a value outside the ordered
    /// set, since there is no sensible place to guess it belongs.
    public func convert(_ value: T?) throws -> Correlithm {
        guard let value else { return missing }
        guard let i = index[value] else { throw CorobsError.argument("'\(value)' is not in this ordinal set.") }
        return try line.atIndex(i, count: index.count)
    }
}

/// A continuous variable on [min, max] (an age, a date, a price) mapped onto a line string CO, or onto
/// a ring when the range wraps (hours of the day, compass bearings).
public final class ContinuousConverter: Converter {
    public typealias Value = Double

    private let string: StringCo
    private let min: Double, max: Double
    private let wraps: Bool

    public let dimensions: Int
    public let missing: Correlithm

    /// A continuous converter over [`min`, `max`] on a fresh string CO of `dimensions` dimensions: a
    /// line, or a ring when `wraps` (the range's two ends are the same position).
    public init(_ prng: SeededPrng, dimensions: Int, min: Double, max: Double, wraps: Bool = false) throws {
        if !(max > min) { throw CorobsError.argument("max must exceed min.") }
        self.string = try wraps ? StringCo.ring(prng, dimensions: dimensions) : StringCo.line(prng, dimensions: dimensions)
        (self.min, self.max, self.wraps) = (min, max, wraps)
        self.dimensions = dimensions
        self.missing = try Correlithm.midpoint(dimensions)
    }

    /// The value's point on the string (`missing` for `nil`, NaN, or an infinite value on a ring,
    /// which has no phase to land on).
    public func convert(_ value: Double?) throws -> Correlithm {
        guard let value, !value.isNaN else { return missing }
        // The reference's COR-T5 decision (docs/BUGS.md): a ring has no phase for infinity.
        if wraps && value.isInfinite { return missing }
        let t = (value - min) / (max - min)
        return try string.at(t)
    }
}

/// A point in a bounded plane (a map position) on a planar string CO (Fig. VII-10).
public final class PlanarConverter: Converter {
    public typealias Value = (x: Double, y: Double)

    private let plane: StringCo
    private let minX: Double, maxX: Double, minY: Double, maxY: Double

    public let dimensions: Int
    public let missing: Correlithm

    /// A planar converter over the rectangle [`minX`, `maxX`] × [`minY`, `maxY`] on a fresh planar
    /// string CO of `dimensions` dimensions.
    public init(_ prng: SeededPrng, dimensions: Int, minX: Double, maxX: Double, minY: Double, maxY: Double) throws {
        if !(maxX > minX) || !(maxY > minY) { throw CorobsError.argument("Each axis needs max > min.") }
        self.plane = try StringCo.plane(prng, dimensions: dimensions)
        (self.minX, self.maxX, self.minY, self.maxY) = (minX, maxX, minY, maxY)
        self.dimensions = dimensions
        self.missing = try Correlithm.midpoint(dimensions)
    }

    /// The value's point on the plane (`missing` for `nil` or a NaN coordinate).
    public func convert(_ value: (x: Double, y: Double)?) throws -> Correlithm {
        guard let value, !value.x.isNaN, !value.y.isNaN else { return missing }
        let (x, y) = value
        return try plane.at(x: (x - minX) / (maxX - minX), y: (y - minY) / (maxY - minY))
    }
}
