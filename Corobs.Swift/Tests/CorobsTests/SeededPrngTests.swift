import Corobs
import Testing

@Suite struct SeededPrngTests {
    @Test func sameSeedSameStream() {
        let a = SeededPrng(42)
        let b = SeededPrng(42)
        for _ in 0..<1000 { #expect(a.nextUInt64() == b.nextUInt64()) }
    }

    @Test func differentSeedsDiffer() {
        let a = SeededPrng(1)
        let b = SeededPrng(2)
        let xs = (0..<16).map { _ in a.nextUInt64() }
        let ys = (0..<16).map { _ in b.nextUInt64() }
        #expect(xs != ys)
    }

    @Test func doublesAreUniformOnTheUnitInterval() {
        let p = SeededPrng(99)
        let xs = (0..<20000).map { _ in p.nextDouble() }
        #expect(xs.allSatisfy { $0 >= 0 && $0 < 1 })
        #expect(near(mean(xs), 0.5, within: 0.01))
    }

    @Test func deriveIsDeterministicAndIndependentOfConsumption() {
        let a = SeededPrng(5)
        _ = a.nextUInt64()
        _ = a.nextUInt64()
        let b = SeededPrng(5)
        #expect(a.derive("faction").seed == b.derive("faction").seed)
        #expect(a.derive("faction").seed != b.derive("turf").seed)
        #expect(a.derive("faction").seed != a.seed)
    }

    @Test func nextNeedsAPositiveBound() {
        #expect(throws: CorobsError.self) { try SeededPrng(1).next(0) }
    }
}
