import Corobs
import Foundation
import Testing

/// Table II-1 and Ch. III, checked against the cube itself.
@Suite struct NCubeTests {
    @Test(arguments: [64, 100])
    func randomPointsSitAtStandardDistanceWithTheBooksDeviation(n: Int) throws {
        let prng = SeededPrng(2004)
        var distances: [Double] = []
        for _ in 0..<3000 {
            let a = try Correlithm.random(prng, dimensions: n)
            let b = try Correlithm.random(prng, dimensions: n)
            distances.append(try a.distance(to: b))
        }
        let m = mean(distances)
        let sd = (distances.reduce(0) { $0 + ($1 - m) * ($1 - m) } / Double(distances.count - 1)).squareRoot()
        #expect(near(m, try NCube.standardDistance(n), within: 0.03), "μ = √(N/6)")
        #expect(near(sd, NCube.standardDeviation, within: 0.025), "σ = √(7/120), independent of N")
    }

    @Test(arguments: [64, 100])
    func midpointAndCornerDistancesMatchTheTable(n: Int) throws {
        let prng = SeededPrng(7)
        let mid = try Correlithm.midpoint(n)
        let corner = try Correlithm([Double](repeating: 0, count: n))
        var toMid: [Double] = [], toCorner: [Double] = []
        for _ in 0..<2000 {
            let p = try Correlithm.random(prng, dimensions: n)
            toMid.append(try p.distance(to: mid))
            toCorner.append(try p.distance(to: corner))
        }
        #expect(near(mean(toMid), try NCube.standardRadius(n), within: 0.02), "standard radius √(N/12)")
        #expect(near(mean(toCorner), try NCube.standardDiameter(n), within: 0.03), "standard diameter √(N/3)")
        #expect(near(try NCube.halfDiagonal(n), try mid.distance(to: corner), within: 1e-12))
    }

    @Test func bitContentFollowsEquationIIIH() throws {
        let n = 100
        let mu = try NCube.standardDistance(n)
        #expect(try NCube.bitContent(n, mu) == 0)
        #expect(try NCube.bitContent(n, mu + 1) == 0, "beyond μ carries nothing")
        // 24.75·(μ−d)² is the book's rounded form of ((μ−d)/σ)²/ln 2.
        #expect(near(try NCube.bitContent(n, mu - 1), 24.75, within: 0.1))
        // Rule of thumb: a little over four bits per dimension at d = 0.
        #expect(near(try NCube.bitContent(n, 0) / Double(n), 4.12, within: 0.02))
        #expect(near(try NCube.distanceForBits(n, 24.75), mu - 1, within: 0.005))
    }

    @Test func probabilityOfProximityIsTwoToTheMinusBits() throws {
        let n = 100
        let mu = try NCube.standardDistance(n)
        #expect(try NCube.probabilityOfProximity(n, mu) == 1)
        // Eq. III-J: 10^(−7.45(μ−d)²); at μ−d = 0.5 → 10^−1.86.
        #expect(near(log10(try NCube.probabilityOfProximity(n, mu - 0.5)), -1.86, within: 0.02))
    }

    @Test func pointCapacityFollowsEquationIIIQ() throws {
        // Book: N=96, d=1.0 → about 10^33 points before a pair falls within 1.0 of each other.
        #expect(near(log10(try NCube.pointCapacity(96, 1.0)), 33.3, within: 0.3))
        #expect(try NCube.pointCapacity(96, try NCube.standardDistance(96)) == 1)
    }

    @Test func deviationsAndDistancesRoundTrip() throws {
        let n = 64
        let d = try NCube.distanceAtDeviations(n, 6)
        #expect(near(try NCube.deviationsBelow(n, d), 6, within: 1e-9))
        #expect(near(try NCube.bitContent(n, d), 36 / log(2.0), within: 1e-9), "6σ ≈ 52 bits")
    }

    @Test func aSpaceNeedsADimension() {
        #expect(throws: CorobsError.self) { try NCube.standardDistance(0) }
        #expect(throws: CorobsError.self) { try NCube.distanceForBits(64, -1) }
    }
}

@Suite struct CorrelithmTests {
    @Test func coordinatesMustLieInTheUnitCube() {
        #expect(throws: CorobsError.self) { try Correlithm([]) }
        #expect(throws: CorobsError.self) { try Correlithm([0.5, 1.5]) }
        #expect(throws: CorobsError.self) { try Correlithm([Double.nan]) }
    }

    @Test func pointsFromDifferentSpacesHaveNoDistance() throws {
        let a = try Correlithm.midpoint(4)
        let b = try Correlithm.midpoint(5)
        #expect(throws: CorobsError.self) { try a.distance(to: b) }
    }

    @Test func centroidAndInterpolation() throws {
        let a = try Correlithm([0, 0])
        let b = try Correlithm([1, 0.5])
        #expect(try Correlithm.centroid([a, b]) == (try Correlithm([0.5, 0.25])))
        #expect(try a.interpolate(toward: b, fraction: 0.5) == (try Correlithm([0.5, 0.25])))
        #expect(throws: CorobsError.self) { try a.interpolate(toward: b, fraction: 2) }
        #expect(a.description == "CO[2]")
    }
}
