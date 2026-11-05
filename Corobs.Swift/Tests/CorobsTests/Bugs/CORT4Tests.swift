import Corobs
import Testing

/// COR-T4 (docs/BUGS.md). Each test asserts an invariant, not an implementation. The old code lives
/// only in the C# reference, behind its symbols; here the fixed behaviour must satisfy the invariant.
@Suite struct CORT4Tests {
    @Test func thresholdNoPatternMemberIsLinkedByAPairShortOfTheRequiredSigma() throws {
        let n = 4
        let miner = try PatternMiner(minDeviations: 6, minMembers: 5)
        #expect(try NCube.distanceAtDeviations(n, miner.minDeviations) < 0, "precondition: μ − 6σ < 0 at N = 4")

        let points = try (0..<5).map { k in PlyPoint(id: k, point: try Correlithm([0.1 * Double(k), 0.5, 0.5, 0.5])) }

        for pattern in try miner.mine(points) {
            for id in pattern.members {
                let p = points[id].point
                var best = -Double.infinity
                for other in pattern.members where other != id {
                    best = max(best, try NCube.deviationsBelow(n, p.distance(to: points[other].point)))
                }
                #expect(best >= miner.minDeviations,
                        "member \(id) joined a \(miner.minDeviations)σ pattern though its closest partner is only \(best)σ below μ")
            }
        }
    }

    @Test(arguments: [Double.infinity, -Double.infinity])
    func ringAtNeverReturnsAPointOffTheRing(t: Double) throws {
        let n = 32
        let ring = try StringCo.ring(SeededPrng(42), dimensions: n)

        let p: Correlithm
        do {
            p = try ring.at(t)
        } catch let error as CorobsError {
            guard case .argumentOutOfRange = error else { throw error }
            return
        }

        // A ring takes exactly 2N distinct points, one per arc between its 2N breakpoints.
        var onRing = Set<Correlithm>()
        let steps = 200_000
        for k in 0..<steps { onRing.insert(try ring.at(Double(k) / Double(steps))) }
        #expect(onRing.count == 2 * n, "precondition: the grid visits every ring point")
        #expect(onRing.contains(p), "at(\(t)) returned a point the ring never visits (book Ch. IX, p. 123: exactly on the string)")
    }

    @Test func pairsAPerfectPredictorRecoversEveryHiddenRelationshipEvenWhenListedRepeatedly() throws {
        var pairs: [(Int, Int)] = []
        for i in 0..<20 {
            pairs.append((2 * i, 2 * i + 1))
            pairs.append((2 * i, 2 * i + 1))
            pairs.append((2 * i + 1, 2 * i))
        }
        let r = try Bench.holdoutRecall(pairs, holdoutFraction: 0.5, seed: 7, neighbours: oracle(pairs) { $0 })
        #expect(r.recall == 1.0, "perfect predictor scored recall \(r.recall) (hidden \(r.hidden), recovered \(r.recovered))")
    }

    @Test func pairsOneRelationshipUnderTheCallersComparerIsHiddenOnce() throws {
        let key: (String) -> String = { $0.uppercased() }
        var pairs: [(String, String)] = []
        for i in 0..<20 {
            pairs.append(("a\(i)", "B\(i)"))
            pairs.append(("b\(i)", "A\(i)"))
        }
        let r = try Bench.holdoutRecall(pairs, holdoutFraction: 0.5, seed: 7, key: key, neighbours: oracle(pairs, key: key))
        #expect(r.hidden == 10, "20 relationships, half hidden; each spelled two ways is still one relationship")
    }
}
