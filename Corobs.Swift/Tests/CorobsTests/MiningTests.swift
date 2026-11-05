import Corobs
import Testing

@Suite struct MiningTests {
    let n = 64

    @Test func aPlantedClusterAmongRandomPointsIsTheOnlyPattern() throws {
        let prng = SeededPrng(100)
        var points: [PlyPoint<Int>] = []
        for i in 0..<1000 { points.append(PlyPoint(id: i, point: try Correlithm.random(prng, dimensions: n))) }
        let centre = try Correlithm.random(prng, dimensions: n)
        for i in 1000..<1006 { points.append(PlyPoint(id: i, point: try nearPoint(centre, prng, 0.05))) }

        let patterns = try PatternMiner(minDeviations: 6, minMembers: 5).mine(points)

        #expect(patterns.count == 1)
        #expect(Set(patterns[0].members) == Set(1000..<1006))
        #expect(patterns[0].bits > (try NCube.bitContent(n, NCube.distanceAtDeviations(n, 6))))
        #expect(patterns[0].radius < patterns[0].meanPairDistance)
    }

    @Test func randomPointsAloneYieldNoPattern() throws {
        let prng = SeededPrng(101)
        let points = try (0..<1500).map { PlyPoint(id: $0, point: try Correlithm.random(prng, dimensions: n)) }
        #expect(try PatternMiner().mine(points).isEmpty)
    }

    @Test func miningIsDeterministic() throws {
        func make() throws -> [PlyPoint<Int>] {
            let p = SeededPrng(102)
            return try (0..<300).map { i in
                PlyPoint(id: i, point: try (i < 8 ? nearPoint(Correlithm.midpoint(n), p, 0.05) : Correlithm.random(p, dimensions: n)))
            }
        }
        let a = try PatternMiner().mine(make())
        let b = try PatternMiner().mine(make())
        #expect(a.map(\.members) == b.map(\.members))
        #expect(a.map(\.bits) == b.map(\.bits))
    }

    @Test func aRuleEmergesAndTheOneMemberThatBreaksItIsTheTopHit() throws {
        let prng = SeededPrng(103)
        let cs = try Correlithm.random(prng, dimensions: n) // where the faction sits on ply s
        let ct = try Correlithm.random(prng, dimensions: n) // where its turf sits on ply t

        var s: [PlyPoint<Int>] = [], t: [PlyPoint<Int>] = []
        for id in 1...10 { s.append(PlyPoint(id: id, point: try nearPoint(cs, prng, 0.05))) } // ten members of one faction
        for id in 1...9 { t.append(PlyPoint(id: id, point: try nearPoint(ct, prng, 0.05))) }  // nine share the turf
        t.append(PlyPoint(id: 10, point: try Correlithm.random(prng, dimensions: n)))           // one lives somewhere unrelated
        for id in 11...40 {
            s.append(PlyPoint(id: id, point: try Correlithm.random(prng, dimensions: n)))
            t.append(PlyPoint(id: id, point: try Correlithm.random(prng, dimensions: n)))
        }

        let miner = try PatternMiner()
        let ps = try miner.mine(s)
        let pt = try miner.mine(t)
        #expect(ps.count == 1)
        #expect(pt.count == 1)

        let rules = try RuleMiner(minSupport: 0.8).mine(sourcePly: "faction", source: ps, targetPly: "turf", target: pt)
        try #require(rules.count == 1)
        #expect(near(rules[0].support, 0.9, within: 1e-9))

        let plies: [String: [Int: Correlithm]] = [
            "faction": Dictionary(uniqueKeysWithValues: s.map { ($0.id, $0.point) }),
            "turf": Dictionary(uniqueKeysWithValues: t.map { ($0.id, $0.point) }),
        ]
        let hits = try Cue().find(rules, plies: plies)
        try #require(hits.count == 1)
        #expect(hits[0].id == 10)
        #expect(hits[0].rank == 1)
        #expect(hits[0].bits > 0)
        #expect(hits[0].targetDistance > (try NCube.distanceAtDeviations(n, 1)))
    }

    @Test func aRuleNeedsSupport() throws {
        let prng = SeededPrng(104)
        let cs = try Correlithm.random(prng, dimensions: n)
        let ct = try Correlithm.random(prng, dimensions: n)
        let s = try (1...10).map { PlyPoint(id: $0, point: try nearPoint(cs, prng, 0.05)) }
        let t = try (1...5).map { PlyPoint(id: $0, point: try nearPoint(ct, prng, 0.05)) }
            + (6...10).map { PlyPoint(id: $0, point: try Correlithm.random(prng, dimensions: n)) }
        let miner = try PatternMiner()
        #expect(try RuleMiner(minSupport: 0.8).mine(sourcePly: "a", source: miner.mine(s), targetPly: "b", target: miner.mine(t)).isEmpty,
                "half the members is not a rule")
        #expect(throws: CorobsError.self) {
            try RuleMiner().mine(sourcePly: "a", source: miner.mine(s), targetPly: "a", target: miner.mine(t))
        }
    }

    @Test func minersRefuseNonsenseSettings() {
        #expect(throws: CorobsError.self) { try PatternMiner(minDeviations: 0) }
        #expect(throws: CorobsError.self) { try PatternMiner(minMembers: 1) }
        #expect(throws: CorobsError.self) { try RuleMiner(minSupport: 1.5) }
        #expect(throws: CorobsError.self) { try Cue(targetDeviations: -1) }
    }
}
