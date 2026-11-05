# Corobs for Swift

The Swift port of [Corobs](../README.md), Correlithm Object technology after Lawrence's
*Correlithm Object Technology* (2004). It reproduces the C# reference (`Corobs.Csharp/`) bit for bit
under the same seed, proven by `Tests/CorobsTests/ConformanceTests.swift` against
[`conformance/vectors.json`](../conformance/README.md).

- **No dependencies.** `Package.swift` declares none; the library imports only the platform C
  runtime (`Darwin`, `ucrt`, `Glibc` or `Musl`) for `cos`, `sin`, `log` and `pow`. Not even Foundation.
- **Fixed behaviour only.** The bug ledger and the old code behind `COROBS_BUG_*` symbols live in the
  C# reference; this port carries the fixed behaviour and the same invariant tests (`Tests/CorobsTests/Bugs/`).

## Use

```swift
// Package.swift
.package(path: "../Corobs/Corobs.Swift")   // or a git URL once published
// target dependency: .product(name: "Corobs", package: "Corobs")
```

```swift
import Corobs

let seed = SeededPrng(2004)
let faction = try CardinalConverter<String>(seed.derive("faction"), dimensions: 64)
let tier = try OrdinalConverter(seed.derive("tier"), dimensions: 64, order: ["street", "runner", "fixer", "corpo"])
let hour = try ContinuousConverter(seed.derive("hour"), dimensions: 64, min: 0, max: 24, wraps: true)

let a = try faction.convert("Underclan")
let b = try faction.convert("Arcturus")
let d = try a.distance(to: b)                       // ≈ μ = √(64/6) ≈ 3.27: strangers
print(try NCube.bitContent(64, d))                  // ≈ 0 bits: proximity by chance

let late = try hour.convert(23.5), early = try hour.convert(0.5)
print(try late.distance(to: early) < (try late.distance(to: hour.convert(12))))   // true: the ring wraps

// Mine one ply, propose rules across two, and cue the members that break them.
let points = try (0..<20).map { PlyPoint(id: $0, point: try Correlithm.random(seed, dimensions: 64)) }
let patterns = try PatternMiner().mine(points)      // [] here: random points hold no truths
```

## API at a glance

| C# reference | Swift |
|---|---|
| `NCube.StandardDistance(n)` … | `NCube.standardDistance(n)` … (`throws`) |
| `SeededPrng`, `.Derive`, `.NextDouble`, `.Next` | `SeededPrng`, `.derive`, `.nextDouble()`, `.next(_:)` |
| `Correlithm`, `.DistanceTo`, `.Interpolate`, `.Centroid` | `Correlithm` (value type), `.distance(to:)`, `.interpolate(toward:fraction:)`, `.centroid(_:)` |
| `StringCo.Line/Ring/Plane`, `.At`, `.AtIndex` | `StringCo.line/ring/plane(_:dimensions:)`, `.at(_:)`, `.at(x:y:)`, `.atIndex(_:count:)` |
| `IConverter<T>` and the four converters | `Converter` protocol (`associatedtype Value`); `nil` is missing |
| `PatternMiner`, `RuleMiner`, `Cue` | same names; comparers become `by:` closures, equality is `Hashable` |
| `Bench.HoldoutRecall/Reach/CascadeYield` | `Bench.holdoutRecall(_:holdoutFraction:seed:key:neighbours:)`, `.reach`, `.cascadeYield` |
| `ArgumentOutOfRangeException` / `ArgumentException` / `InvalidOperationException` | `CorobsError.argumentOutOfRange` / `.argument` / `.invalidOperation` |

Every call the reference refuses with an exception `throws` here, including a distance between points
of different dimensionality.

## Build and test

```
swift build --build-tests
swift test                      # or, from the repo root: pwsh ./build.ps1 -Profile Swift -Test
```

Tests use [Swift Testing](https://github.com/swiftlang/swift-testing) (`import Testing`), and read
`../conformance/vectors.json` relative to their own source file.

**Windows.** Build from a Visual Studio x64 developer prompt (`vcvars64.bat`) with `SDKROOT` set to
the Swift Windows SDK (`…\Swift\Platforms\<ver>\Windows.platform\Developer\SDKs\Windows.sdk`). With
Swift 6.4.2 the default build system does not pass the UCRT headers through (`'stdlib.h' file not
found`); add `--build-system native` to `swift build` and `swift test`.
