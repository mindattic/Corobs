import Foundation
import Testing

/// Corobs is pure: the package declares no dependency, and the library imports nothing but the
/// platform's C runtime (for cos, sin, log and pow), so no I/O, network or LLM client is reachable.
@Suite struct PurityTests {
    @Test func thePackageDeclaresNoDependencies() throws {
        let manifest = try String(contentsOf: packageDirectory.appendingPathComponent("Package.swift"), encoding: .utf8)
        #expect(!manifest.contains(".package("))
    }

    @Test func theLibraryImportsOnlyTheCRuntime() throws {
        let sources = packageDirectory.appendingPathComponent("Sources").appendingPathComponent("Corobs")
        let files = try FileManager.default.contentsOfDirectory(atPath: sources.path).filter { $0.hasSuffix(".swift") }
        #expect(!files.isEmpty)
        let allowed: Set<String> = ["Darwin", "ucrt", "Glibc", "Musl"]
        for file in files {
            let text = try String(contentsOf: sources.appendingPathComponent(file), encoding: .utf8)
            for line in text.split(whereSeparator: \.isNewline) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard trimmed.hasPrefix("import ") else { continue }
                let module = String(trimmed.dropFirst("import ".count)).trimmingCharacters(in: .whitespaces)
                #expect(allowed.contains(module), "\(file) imports \(module)")
            }
        }
    }
}
