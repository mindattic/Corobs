import Corobs
import Testing

@Suite struct BenchTests {
    @Test func holdoutRecallCountsHiddenPairsThePredictorRecovers() throws {
        let pairs = (0..<20).map { ("a\($0)", "b\($0)") }
        // A predictor that knows every pair recovers everything with perfect precision.
        let all = oracle(pairs) { $0 }
        let perfect = try Bench.holdoutRecall(pairs, holdoutFraction: 0.25, seed: 1, neighbours: all)
        #expect(perfect.hidden == 5)
        #expect(perfect.recall == 1)
        #expect(perfect.precision == 1)
        // A predictor that knows nothing recovers nothing.
        let blind = try Bench.holdoutRecall(pairs, holdoutFraction: 0.25, seed: 1) { _ in [] }
        #expect(blind.recall == 0)
        // Same seed, same hidden set.
        #expect(try Bench.holdoutRecall(pairs, holdoutFraction: 0.25, seed: 1) { _ in [] }.hidden == blind.hidden)
        #expect(throws: CorobsError.self) { try Bench.holdoutRecall(pairs, holdoutFraction: 1, seed: 1) { _ in [] } }
    }

    @Test func reachCountsHopsAndIsolatedRecords() throws {
        let adj: [Int: [Int]] = [1: [2], 2: [1, 3], 3: [2], 4: []]
        let r = try Bench.reach([1, 2, 3, 4], maxHops: 2) { adj[$0]! }
        #expect(r.isolated == 1)
        #expect(r.total == 4)
        #expect(r.meanReachableByHop[0] == Double(1 + 2 + 1 + 0) / 4.0)
        #expect(r.meanReachableByHop[1] == Double(2 + 2 + 2 + 0) / 4.0)
        #expect(throws: CorobsError.self) { try Bench.reach([1], maxHops: 0) { adj[$0]! } }
    }

    @Test func cascadeYieldIsClosedByCascadePerDirectFix() {
        #expect(Bench.cascadeYield(closedByCascade: 6, directFixes: 4) == 1.5)
        #expect(Bench.cascadeYield(closedByCascade: 0, directFixes: 0) == 0)
    }
}
