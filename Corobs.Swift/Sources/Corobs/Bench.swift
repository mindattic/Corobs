/// How well a neighbour function recovers relationships that were hidden from it.
public struct RecallResult: Equatable, Sendable {
    public let hidden: Int
    public let recovered: Int
    public let predicted: Int
    public let predictedTrue: Int

    public init(hidden: Int, recovered: Int, predicted: Int, predictedTrue: Int) {
        (self.hidden, self.recovered, self.predicted, self.predictedTrue) = (hidden, recovered, predicted, predictedTrue)
    }

    /// Share of the hidden pairs that the predictor recovered.
    public var recall: Double { hidden == 0 ? 0 : Double(recovered) / Double(hidden) }
    /// Share of the predictor's own guesses that were actually true (anywhere in the full truth).
    public var precision: Double { predicted == 0 ? 0 : Double(predictedTrue) / Double(predicted) }
}

/// How far a thing can reach through a relationship: mean reachable count per hop and how many things
/// reach nothing at all (dead records).
public struct ReachResult: Equatable, Sendable {
    public let meanReachableByHop: [Double]
    public let isolated: Int
    public let total: Int

    public init(meanReachableByHop: [Double], isolated: Int, total: Int) {
        (self.meanReachableByHop, self.isolated, self.total) = (meanReachableByHop, isolated, total)
    }
}

/// Scores any way of relating things against any other on the same ground truth: the old way and the
/// Corobs way answer the same questions, and these are the questions. Everything here is arithmetic
/// over ids; the caller supplies the truth and the predictors.
public enum Bench {
    /// Hide `holdoutFraction` of the true relationships (deterministically, by seed), ask the predictor
    /// for each hidden endpoint's neighbours, and count how many hidden relationships come back.
    /// Precision counts predicted neighbours of those endpoints that are true pairs anywhere in the full
    /// truth. A relationship is an unordered pair; ids are equal when their `key`s are.
    public static func holdoutRecall<TId: CustomStringConvertible, Key: Hashable>(
        _ truePairs: [(TId, TId)], holdoutFraction: Double, seed: Int64,
        key: (TId) -> Key, neighbours: (TId) -> [TId]
    ) throws -> RecallResult {
        if holdoutFraction <= 0 || holdoutFraction >= 1 {
            throw CorobsError.argumentOutOfRange("holdoutFraction must lie in (0, 1).")
        }
        func pairKey(_ p: (TId, TId)) -> UnorderedKey<Key> { UnorderedKey(key(p.0), key(p.1)) }

        let truth = Set(truePairs.map { pairKey(canon($0)) })

        let prng = SeededPrng(seed)
        // The reference's COR-T4 fix (docs/BUGS.md): a pair listed twice, or both ways round, is one
        // relationship to hide.
        var seenOnce = Set<UnorderedKey<Key>>()
        var shuffled: [(TId, TId)] = []
        for p in truePairs {
            let c = canon(p)
            if seenOnce.insert(pairKey(c)).inserted { shuffled.append(c) }
        }
        var i = shuffled.count - 1
        while i > 0 {
            let j = try prng.next(i + 1)
            shuffled.swapAt(i, j)
            i -= 1
        }
        let rounded = (Double(shuffled.count) * holdoutFraction).rounded(.toNearestOrEven)
        let take = rounded.isNaN ? 0 : Int(rounded)
        let hidden = shuffled.prefix(take).map { canon($0) }
        var hiddenSet = Set(hidden.map(pairKey))

        var endpointKeys = Set<Key>()
        var endpoints: [TId] = []
        for (a, b) in hidden {
            if endpointKeys.insert(key(a)).inserted { endpoints.append(a) }
            if endpointKeys.insert(key(b)).inserted { endpoints.append(b) }
        }

        var recovered = 0, predicted = 0, predictedTrue = 0
        var seen = Set<UnorderedKey<Key>>()
        for e in endpoints {
            for nb in neighbours(e) {
                let k = pairKey(canon((e, nb)))
                if !seen.insert(k).inserted { continue }
                predicted += 1
                if truth.contains(k) { predictedTrue += 1 }
                if hiddenSet.remove(k) != nil { recovered += 1 }
            }
        }
        return RecallResult(hidden: hidden.count, recovered: recovered, predicted: predicted, predictedTrue: predictedTrue)
    }

    /// `holdoutRecall` with ids compared by their own equality.
    public static func holdoutRecall<TId: Hashable & CustomStringConvertible>(
        _ truePairs: [(TId, TId)], holdoutFraction: Double, seed: Int64, neighbours: (TId) -> [TId]
    ) throws -> RecallResult {
        try holdoutRecall(truePairs, holdoutFraction: holdoutFraction, seed: seed, key: { $0 }, neighbours: neighbours)
    }

    /// Breadth-first reach from every id through `adjacency`, up to `maxHops`.
    public static func reach<TId: Hashable>(_ ids: [TId], maxHops: Int, adjacency: (TId) -> [TId]) throws -> ReachResult {
        if maxHops <= 0 { throw CorobsError.argumentOutOfRange("maxHops must be positive.") }
        var sums = [Double](repeating: 0, count: maxHops)
        var isolated = 0
        for start in ids {
            var visited: Set<TId> = [start]
            var frontier = [start]
            var reached = 0
            for hop in 0..<maxHops {
                var next: [TId] = []
                for f in frontier {
                    for a in adjacency(f) where visited.insert(a).inserted { next.append(a) }
                }
                reached += next.count
                sums[hop] += Double(reached)
                frontier = next
                if next.isEmpty {
                    for h in (hop + 1)..<maxHops { sums[h] += Double(reached) }
                    break
                }
            }
            if reached == 0 { isolated += 1 }
        }
        let means = sums.map { ids.isEmpty ? 0 : $0 / Double(ids.count) }
        return ReachResult(meanReachableByHop: means, isolated: isolated, total: ids.count)
    }

    /// Hits that closed because something else was fixed, per direct fix. The old way scores zero by
    /// construction; that is a fact to report, not to hide.
    public static func cascadeYield(closedByCascade: Int, directFixes: Int) -> Double {
        directFixes == 0 ? 0 : Double(closedByCascade) / Double(directFixes)
    }

    /// Orders a pair by its ids' text, compared by UTF-16 code unit as the reference's
    /// `string.CompareOrdinal(a.ToString(), b.ToString())` does ("10" before "9").
    private static func canon<TId: CustomStringConvertible>(_ p: (TId, TId)) -> (TId, TId) {
        p.1.description.utf16.lexicographicallyPrecedes(p.0.description.utf16) ? (p.1, p.0) : p
    }
}

/// An unordered pair of keys: (a, b) and (b, a) are one relationship.
struct UnorderedKey<Key: Hashable>: Hashable {
    let a: Key, b: Key

    init(_ a: Key, _ b: Key) { (self.a, self.b) = (a, b) }

    static func == (l: UnorderedKey, r: UnorderedKey) -> Bool {
        (l.a == r.a && l.b == r.b) || (l.a == r.b && l.b == r.a)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(Set([a, b]))
    }
}
