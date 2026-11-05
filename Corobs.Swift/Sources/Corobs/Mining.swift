/// One thing's position on one ply (subspace).
public struct PlyPoint<TId: Hashable>: Hashable {
    public let id: TId
    public let point: Correlithm

    public init(id: TId, point: Correlithm) {
        self.id = id
        self.point = point
    }
}

/// An emergent truth: a set of things whose points on one ply lie far closer together than chance
/// allows. Proposed by `PatternMiner`; what it *means*, and whether it is true, is the caller's hand
/// decision.
public final class Pattern<TId: Hashable>: CustomStringConvertible {
    /// The ids of the things in this cluster.
    public let members: [TId]
    /// The mean point of the members: what a rule's source or target pattern pulls toward.
    public let centroid: Correlithm
    /// The furthest any member lies from the centroid.
    public let radius: Double
    /// The mean distance between members, pairwise.
    public let meanPairDistance: Double
    /// Eq. III-H bits of the mean pair distance: how far below chance this cluster is.
    public let bits: Double

    private let set: Set<TId>

    /// A pattern over the given members and their already-computed geometry; callers normally get one
    /// from `PatternMiner` rather than constructing it directly.
    public init(members: [TId], centroid: Correlithm, radius: Double, meanPairDistance: Double, bits: Double) {
        self.members = members
        self.centroid = centroid
        self.radius = radius
        self.meanPairDistance = meanPairDistance
        self.bits = bits
        self.set = Set(members)
    }

    /// Whether `id` is one of this pattern's members.
    public func contains(_ id: TId) -> Bool { set.contains(id) }

    /// The member count and bits, for logs and reports.
    public var description: String { "Pattern[\(members.count) members, \(fixed1(bits)) bits]" }
}

/// Finds the clusters on one ply that are far tighter than chance: two points are linked when they lie
/// at least `minDeviations` σ below standard distance (≈ 52 bits at 6σ, Eq. III-H), linked points are
/// joined by union-find, and a component with at least `minMembers` members is a proposed `Pattern`.
/// Deterministic: points are processed in id order, and the output is ordered by bits then by first
/// member.
public final class PatternMiner {
    /// The linking threshold, in σ below standard distance (default 6, ≈ 52 bits).
    public let minDeviations: Double
    /// The smallest cluster size kept as a pattern (default 5).
    public let minMembers: Int

    /// A miner that links points at `minDeviations` σ below standard distance and keeps clusters of at
    /// least `minMembers`.
    public init(minDeviations: Double = 6, minMembers: Int = 5) throws {
        if minDeviations <= 0 { throw CorobsError.argumentOutOfRange("minDeviations must be positive.") }
        if minMembers < 2 { throw CorobsError.argumentOutOfRange("minMembers must be at least 2.") }
        self.minDeviations = minDeviations
        self.minMembers = minMembers
    }

    /// The patterns found among `points` (all on the same ply), ordered by bits descending then by
    /// first member ascending.
    public func mine<TId: Hashable & Comparable>(_ points: [PlyPoint<TId>]) throws -> [Pattern<TId>] {
        try mine(points, by: <)
    }

    /// The patterns found among `points`, with ids ordered by `areInIncreasingOrder`.
    public func mine<TId: Hashable>(_ points: [PlyPoint<TId>], by areInIncreasingOrder: (TId, TId) -> Bool) throws -> [Pattern<TId>] {
        if points.count < minMembers { return [] }
        let n = points[0].point.dimensions
        let sorted = points.stableSorted { areInIncreasingOrder($0.id, $1.id) }
        let threshold = try NCube.distanceAtDeviations(n, minDeviations)
        // The reference's COR-T4 fix (docs/BUGS.md): distance is never negative, so a negative
        // threshold links nothing.
        if threshold < 0 { return [] }
        let thresholdSq = threshold * threshold

        var parent = Array(sorted.indices)
        for i in sorted.indices {
            let pi = sorted[i].point
            for j in (i + 1)..<sorted.count {
                if try pi.squaredDistance(to: sorted[j].point) <= thresholdSq { union(&parent, i, j) }
            }
        }

        var roots: [Int] = []
        var groups: [Int: [Int]] = [:]
        for i in sorted.indices {
            let root = find(&parent, i)
            if groups[root] == nil { roots.append(root); groups[root] = [] }
            groups[root]!.append(i)
        }

        var result: [Pattern<TId>] = []
        for root in roots {
            let members = groups[root]!
            if members.count < minMembers { continue }
            let pts = members.map { sorted[$0].point }
            let centroid = try Correlithm.centroid(pts)
            var radius = -Double.infinity
            for p in pts {
                let d = try p.distance(to: centroid)
                if d > radius { radius = d }
            }
            var sum = 0.0
            var pairs = 0
            for a in pts.indices {
                for b in (a + 1)..<pts.count {
                    let d = try pts[a].distance(to: pts[b])
                    sum += d
                    pairs += 1
                }
            }
            let mean = sum / Double(pairs)
            let bits = try NCube.bitContent(n, mean)
            result.append(Pattern(members: members.map { sorted[$0].id }, centroid: centroid, radius: radius,
                                  meanPairDistance: mean, bits: bits))
        }

        return result.stableSorted { a, b in
            if a.bits != b.bits { return a.bits > b.bits }
            return areInIncreasingOrder(a.members[0], b.members[0])
        }
    }

    private func find(_ parent: inout [Int], _ i: Int) -> Int {
        var i = i
        while parent[i] != i {
            parent[i] = parent[parent[i]]
            i = parent[i]
        }
        return i
    }

    private func union(_ parent: inout [Int], _ a: Int, _ b: Int) {
        let ra = find(&parent, a)
        let rb = find(&parent, b)
        if ra == rb { return }
        if ra < rb { parent[rb] = ra } else { parent[ra] = rb }
    }
}

/// A rule `s.p >: t.q` (Ch. IV): things inside pattern `source` on ply `sourcePly` are found inside
/// pattern `target` on ply `targetPly` with the given `support`. These are the strings that pull.
public struct Rule<TId: Hashable>: CustomStringConvertible {
    public let sourcePly: String
    public let source: Pattern<TId>
    public let targetPly: String
    public let target: Pattern<TId>
    public let support: Double
    public let bits: Double

    public init(sourcePly: String, source: Pattern<TId>, targetPly: String, target: Pattern<TId>, support: Double, bits: Double) {
        (self.sourcePly, self.source, self.targetPly, self.target, self.support, self.bits) =
            (sourcePly, source, targetPly, target, support, bits)
    }

    /// The rule's plies, pattern sizes, support and bits, for logs and reports.
    public var description: String {
        "\(sourcePly).[\(source.members.count)] >: \(targetPly).[\(target.members.count)] support \(percent0(support)), \(fixed1(bits)) bits"
    }
}

/// Proposes rules between the patterns of two plies: for every source pattern, the target pattern that
/// holds the largest share of its members, kept when that share reaches `minSupport`.
/// Bits = support × the source pattern's bits. Deterministic.
public final class RuleMiner {
    /// The smallest share of a source pattern's members that must land in the best target pattern for a
    /// rule to be proposed (default 0.8).
    public let minSupport: Double

    /// A miner that proposes rules whose support reaches `minSupport`.
    public init(minSupport: Double = 0.8) throws {
        if minSupport <= 0 || minSupport > 1 { throw CorobsError.argumentOutOfRange("minSupport must lie in (0, 1].") }
        self.minSupport = minSupport
    }

    /// The rules from `sourcePly`'s patterns to `targetPly`'s that reach `minSupport`, ordered by bits
    /// descending.
    public func mine<TId: Hashable>(sourcePly: String, source: [Pattern<TId>], targetPly: String, target: [Pattern<TId>]) throws -> [Rule<TId>] {
        if sourcePly == targetPly { throw CorobsError.argument("A rule relates two different plies.") }
        var rules: [Rule<TId>] = []
        for p in source {
            var best: Pattern<TId>?
            var bestCount = 0
            for q in target {
                let count = p.members.filter(q.contains).count
                if count > bestCount { best = q; bestCount = count }
            }
            guard let best else { continue }
            let support = Double(bestCount) / Double(p.members.count)
            if support >= minSupport {
                rules.append(Rule(sourcePly: sourcePly, source: p, targetPly: targetPly, target: best, support: support, bits: support * p.bits))
            }
        }
        return rules.stableSorted { $0.bits > $1.bits }
    }
}

/// A ranked contradiction candidate: a thing that sits inside a rule's source pattern yet lies at or
/// near standard distance from the rule's target, the anomaly a cueing system hands to the expert
/// (Ch. X–XI). What to do about it is the caller's hand decision.
public struct Hit<TId: Hashable>: CustomStringConvertible {
    public let id: TId
    public let rule: Rule<TId>
    public let sourceDistance: Double
    public let targetDistance: Double
    public let bits: Double
    public let rank: Int

    /// The hit's rank, id and bits against the rule it violates, for logs and reports.
    public var description: String { "#\(rank) \(id): \(fixed1(bits)) bits — \(rule)" }
}

/// For every rule, every member of its source whose point on the target ply lies no closer than
/// `targetDeviations` σ below standard distance from the target centroid is a hit. Bits = (bits of
/// the member's own distance to the source centroid) × rule support, so a thing deep inside a strong
/// source that misses the target outranks a marginal member of a weak one. Deterministic.
public final class Cue {
    /// How close to the target centroid, in σ below standard distance, a member must land to not count
    /// as a hit (default 1).
    public let targetDeviations: Double

    /// A cueing instrument using `targetDeviations` as the pass/fail line.
    public init(targetDeviations: Double = 1) throws {
        if targetDeviations < 0 { throw CorobsError.argumentOutOfRange("targetDeviations must not be negative.") }
        self.targetDeviations = targetDeviations
    }

    /// The hits for confirmed `rules`, given each ply's points by id keyed by ply name, ranked by bits
    /// descending then id ascending.
    public func find<TId: Hashable & Comparable>(_ rules: [Rule<TId>], plies: [String: [TId: Correlithm]]) throws -> [Hit<TId>] {
        try find(rules, plies: plies, by: <)
    }

    /// The hits, with ids at equal bits ordered by `areInIncreasingOrder`.
    public func find<TId: Hashable>(_ rules: [Rule<TId>], plies: [String: [TId: Correlithm]], by areInIncreasingOrder: (TId, TId) -> Bool) throws -> [Hit<TId>] {
        var hits: [Hit<TId>] = []
        for rule in rules {
            guard let sourcePoints = plies[rule.sourcePly] else { throw CorobsError.argument("No points for ply '\(rule.sourcePly)'.") }
            guard let targetPoints = plies[rule.targetPly] else { throw CorobsError.argument("No points for ply '\(rule.targetPly)'.") }
            let n = rule.target.centroid.dimensions
            let farEnough = try NCube.distanceAtDeviations(n, targetDeviations)
            for id in rule.source.members {
                guard let tp = targetPoints[id], let sp = sourcePoints[id] else { continue }
                let targetDistance = try tp.distance(to: rule.target.centroid)
                if targetDistance < farEnough { continue }
                let sourceDistance = try sp.distance(to: rule.source.centroid)
                let bits = try NCube.bitContent(sp.dimensions, sourceDistance) * rule.support
                hits.append(Hit(id: id, rule: rule, sourceDistance: sourceDistance, targetDistance: targetDistance, bits: bits, rank: 0))
            }
        }
        let ordered = hits.stableSorted { a, b in
            if a.bits != b.bits { return a.bits > b.bits }
            return areInIncreasingOrder(a.id, b.id)
        }
        return ordered.enumerated().map { i, h in
            Hit(id: h.id, rule: h.rule, sourceDistance: h.sourceDistance, targetDistance: h.targetDistance, bits: h.bits, rank: i + 1)
        }
    }
}
