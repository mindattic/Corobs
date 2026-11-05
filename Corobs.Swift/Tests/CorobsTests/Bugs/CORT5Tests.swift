import Corobs
import Testing

/// COR-T5 is a decision, not a proven error (docs/BUGS.md): this pins the chosen behaviour.
@Suite struct CORT5Tests {
    @Test(arguments: [Double.infinity, -Double.infinity])
    func decisionAWrappingConverterMapsInfinityToMissing(value: Double) throws {
        let hours = try ContinuousConverter(SeededPrng(1), dimensions: 32, min: 0, max: 24, wraps: true)
        #expect(try hours.convert(value) == hours.missing)
    }
}
