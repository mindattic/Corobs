import Corobs
import Testing

@Suite struct ConverterTests {
    let n = 128

    @Test func cardinalValuesAreFixedTokensAtStandardDistanceFromEachOther() throws {
        let c = try CardinalConverter<String>(SeededPrng(1), dimensions: n)
        let again = try CardinalConverter<String>(SeededPrng(1), dimensions: n)
        let first = try c.convert("Underclan")
        #expect(try c.convert("Underclan") == first, "a value is one token, cached")
        #expect(try again.convert("Underclan") == first, "same seed, same token, whatever was seen first")
        let mu = try NCube.standardDistance(n)
        #expect(near(try c.convert("Underclan").distance(to: c.convert("Arcturus")) / mu, 1, within: 0.2))
        #expect(try c.convert(nil) == (try Correlithm.midpoint(n)))
    }

    @Test func ordinalNeighboursAreCloserThanExtremesAndUnknownsThrow() throws {
        let tiers = ["street", "runner", "fixer", "corpo", "board"]
        let c = try OrdinalConverter(SeededPrng(2), dimensions: n, order: tiers)
        #expect(try c.convert("street").distance(to: c.convert("runner")) < c.convert("street").distance(to: c.convert("board")))
        #expect(throws: CorobsError.self) { try c.convert("god") }
        #expect(try c.convert(nil) == c.missing)
        #expect(c.count == 5)
        #expect(throws: CorobsError.self) { try OrdinalConverter<String>(SeededPrng(2), dimensions: n, order: []) }
    }

    @Test func continuousValuesInterpolateAndCanWrap() throws {
        let years = try ContinuousConverter(SeededPrng(3), dimensions: n, min: 2200, max: 2300)
        #expect(try years.convert(2230).distance(to: years.convert(2231)) < years.convert(2230).distance(to: years.convert(2290)))
        #expect(try years.convert(nil) == years.missing)
        #expect(try years.convert(Double.nan) == years.missing)

        let hours = try ContinuousConverter(SeededPrng(4), dimensions: n, min: 0, max: 24, wraps: true)
        #expect(try hours.convert(23.5).distance(to: hours.convert(0.5)) < hours.convert(23.5).distance(to: hours.convert(12)))
        #expect(throws: CorobsError.self) { try ContinuousConverter(SeededPrng(4), dimensions: n, min: 1, max: 1) }
    }

    @Test func planarPositionsAreNearWhenTheMapSaysSo() throws {
        let map = try PlanarConverter(SeededPrng(5), dimensions: n, minX: -10, maxX: 10, minY: -10, maxY: 10)
        let here = try map.convert((x: 0, y: 0))
        #expect(try here.distance(to: map.convert((x: 0.5, y: 0.5))) < here.distance(to: map.convert((x: 8, y: -7))))
        #expect(try map.convert(nil) == map.missing)
    }
}
