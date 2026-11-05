/// What a Corobs call refuses, mirroring the reference's exceptions: `ArgumentOutOfRangeException`,
/// `ArgumentException` and `InvalidOperationException`.
public enum CorobsError: Error, Equatable, Sendable {
    /// A value lies outside the range the call accepts (a dimension count, a position, a fraction).
    case argumentOutOfRange(String)
    /// An argument is unusable as given (an empty order, an unknown ordinal value, mismatched spaces).
    case argument(String)
    /// The call does not apply to this object (two coordinates on a line, one on a plane).
    case invalidOperation(String)
}

/// Stable sort: ties keep their input order, as LINQ's `OrderBy` does in the reference.
extension Array {
    func stableSorted(by areInIncreasingOrder: (Element, Element) -> Bool) -> [Element] {
        enumerated()
            .sorted { a, b in
                if areInIncreasingOrder(a.element, b.element) { return true }
                if areInIncreasingOrder(b.element, a.element) { return false }
                return a.offset < b.offset
            }
            .map(\.element)
    }
}

/// `F1` formatting for logs: one decimal, half away from zero.
func fixed1(_ x: Double) -> String {
    guard x.isFinite, abs(x) < 1e15 else { return "\(x)" }
    let scaled = Int((abs(x) * 10).rounded(.toNearestOrAwayFromZero))
    let text = "\(scaled / 10).\(scaled % 10)"
    return x < 0 && scaled != 0 ? "-" + text : text
}

/// `P0` formatting for logs: a whole percentage.
func percent0(_ x: Double) -> String {
    guard x.isFinite, abs(x) < 1e13 else { return "\(x)" }
    return "\(Int((x * 100).rounded(.toNearestOrAwayFromZero)))%"
}
