import Corobs
import Testing

/// Ch. VII: distance along the geometry becomes distance in the cube; strangers stay at μ.
@Suite struct StringCoTests {
    let n = 2048 // large so a single string's statistics are tight

    @Test func lineDistanceGrowsAsRootOfSeparationAndReachesMu() throws {
        let line = try StringCo.line(SeededPrng(11), dimensions: n)
        let mu = try NCube.standardDistance(n)
        let origin = try line.at(0)
        let d1 = try origin.distance(to: line.at(0.1))
        let d3 = try origin.distance(to: line.at(0.3))
        let d6 = try origin.distance(to: line.at(0.6))
        let d10 = try origin.distance(to: line.at(1.0))
        #expect(d1 < d3 && d1 < d6)
        #expect(d3 < d6)
        #expect(d6 < d10)
        #expect(near(d1 / mu, (0.1).squareRoot(), within: 0.06), "≈ μ·√|Δt|")
        #expect(near(d10 / mu, 1, within: 0.06), "the far ends are at standard distance")
        #expect(try origin.distance(to: origin) == 0)
    }

    @Test func ringWraps() throws {
        let ring = try StringCo.ring(SeededPrng(12), dimensions: n)
        let mu = try NCube.standardDistance(n)
        let origin = try ring.at(0)
        #expect(near(try origin.distance(to: ring.at(0.5)) / mu, 1, within: 0.06), "opposite side is μ")
        #expect(try origin.distance(to: ring.at(0.98)) < origin.distance(to: ring.at(0.25)), "0.98 is next to 0")
        #expect(try ring.at(0.3).distance(to: ring.at(1.3)) == 0, "t is taken mod 1")
    }

    @Test func planeIsIsotropic() throws {
        let plane = try StringCo.plane(SeededPrng(13), dimensions: n)
        let origin = try plane.at(x: 0.5, y: 0.5)
        let alongX = try origin.distance(to: plane.at(x: 0.8, y: 0.5))
        let alongY = try origin.distance(to: plane.at(x: 0.5, y: 0.8))
        let step = 0.3 / (2.0).squareRoot()
        let diagonal = try origin.distance(to: plane.at(x: 0.5 + step, y: 0.5 + step))
        #expect(near(alongX, alongY, within: alongY * 0.15))
        #expect(near(diagonal, alongX, within: alongX * 0.2))
        #expect(try origin.distance(to: plane.at(x: 0.55, y: 0.5)) < alongX)
    }

    @Test func everyPositionIsAStrangerToAnUnrelatedPoint() throws {
        let prng = SeededPrng(14)
        let line = try StringCo.line(prng, dimensions: n)
        let stranger = try Correlithm.random(prng, dimensions: n)
        let mu = try NCube.standardDistance(n)
        for t in [0.0, 0.25, 0.5, 0.75, 1.0] {
            #expect(near(try line.at(t).distance(to: stranger) / mu, 1, within: 0.06))
        }
    }

    @Test func ordinalPositionsAreEvenlySpaced() throws {
        let line = try StringCo.line(SeededPrng(15), dimensions: n)
        let a = try line.atIndex(0, count: 26)
        let b = try line.atIndex(1, count: 26)
        let e = try line.atIndex(4, count: 26)
        let z = try line.atIndex(25, count: 26)
        #expect(try a.distance(to: b) < a.distance(to: e))
        #expect(try a.distance(to: e) < a.distance(to: z))
    }

    @Test func sameSeedSameString() throws {
        let a = try StringCo.plane(SeededPrng(16), dimensions: 64).at(x: 0.2, y: 0.7)
        let b = try StringCo.plane(SeededPrng(16), dimensions: 64).at(x: 0.2, y: 0.7)
        #expect(a == b)
    }

    @Test func eachGeometryTakesItsOwnCoordinates() throws {
        let line = try StringCo.line(SeededPrng(17), dimensions: 8)
        let plane = try StringCo.plane(SeededPrng(17), dimensions: 8)
        #expect(throws: CorobsError.self) { try line.at(x: 0.5, y: 0.5) }
        #expect(throws: CorobsError.self) { try plane.at(0.5) }
        #expect(throws: CorobsError.self) { try line.at(Double.nan) }
        #expect(throws: CorobsError.self) { try line.atIndex(3, count: 3) }
    }
}
