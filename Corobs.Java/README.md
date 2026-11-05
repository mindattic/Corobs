# Corobs for Java

The Java port of [Corobs](../README.md): Correlithm Object technology (Lawrence, *Correlithm Object
Technology*, 2004) as a pure, deterministic library. It reproduces the C# reference
(`Corobs.Csharp`) bit for bit under the same seed, proven by `ConformanceTest` against
[`conformance/vectors.json`](../conformance/README.md).

- Java 17+, one module (`com.mindattic.corobs`), **no runtime dependencies** (`PurityTest`).
- Packages: `geometry`, `seeding`, `strings`, `converters`, `mining`, `bench`, plus `Equality` (the
  analogue of .NET's `IEqualityComparer`) in the root package.
- Fixed behaviour only: the bug ledger and the old code behind `COROBS_BUG_*` symbols live in the C#
  reference (`docs/BUGS.md`); the same invariant tests run here under `bugs/`.

## Maven

```xml
<dependency>
  <groupId>com.mindattic</groupId>
  <artifactId>corobs</artifactId>
  <version>0.1.0</version>
</dependency>
```

## Example

```java
var seed = new SeededPrng(2004);
var faction = new CardinalConverter<String>(seed.derive("faction"), 64);
var age = new ContinuousConverter(seed.derive("age"), 64, 0, 120);

List<PlyPoint<Integer>> points = ...;              // one point per thing on one ply
List<Pattern<Integer>> patterns = new PatternMiner().mine(points);
List<Rule<Integer>> rules = new RuleMiner().mine("faction", factionPatterns, "turf", turfPatterns);
List<Hit<Integer>> hits = new Cue().find(rules, plies);   // ranked contradictions for a human to judge
```

Missing values are `null` (and `NaN`); they convert to the cube's midpoint.

## Build and test

```
mvn -DskipTests package     # the jar
mvn test                    # JUnit 5: the book's statistics, invariants, conformance, purity
pwsh ../build.ps1 -Profile Java -Test
```

Tests find the vectors at `../conformance/vectors.json` (Surefire passes the path as the
`corobs.vectors` system property).

## Notes on determinism

`sin`, `cos`, `log` and `pow` go through `StrictMath` (fdlibm), so results do not vary between JVMs.
Java never fuses multiply-add on its own, so sums round exactly as the reference's do.
`Bench.holdoutRecall` rounds half to even (`Math.rint`), as .NET's `Math.Round` does, and orders pair
ids by their `String.valueOf` text compared in UTF-16 code units (`"10" < "9"`).
