# Corobs.jl

The Julia port of [Corobs](../README.md): Correlithm Object technology (P. Nick Lawrence,
*Correlithm Object Technology*, 2004) as a pure, deterministic package with no dependencies. It
reproduces the C# reference implementation bit for bit under the same seed, checked against the
shared [conformance vectors](../conformance/README.md).

## Install

```julia
using Pkg
Pkg.develop(path = "path/to/Corobs/Corobs.Julia")   # or Pkg.add(url = ..., subdir = "Corobs.Julia")
```

## Use

```julia
using Corobs

root = SeededPrng(2004)
n = 64

faction = CardinalConverter(derive(root, "faction"), n)
tier    = OrdinalConverter(derive(root, "tier"), n, ["street", "runner", "fixer", "corpo"])
hours   = ContinuousConverter(derive(root, "hour"), n, 0, 24; wraps = true)

a = topoint(faction, "Underclan")
b = topoint(faction, "Arcturus")
distance(a, b) / standard_distance(n)          # ≈ 1: unrelated tokens sit at standard distance
bit_content(n, distance(topoint(hours, 23.5), topoint(hours, 0.5)))   # bits in a near miss

points = [PlyPoint(i, topoint(tier, t)) for (i, t) in enumerate(["street", "street", "runner"])]
patterns = mine(PatternMiner(), points)        # clusters far tighter than chance (needs ≥ 5 members)
```

Missing values are `nothing` (or `missing`) and land on `missingpoint(converter)`, the cube's
midpoint. Indexes are 1-based (`at_index(line, 1, count)` is the first position). The string-CO
module is `StringCOs` (not `Strings`), with `line_co`, `ring_co` and `plane_co`.

| C# | Julia |
|---|---|
| `NCube.StandardDistance(n)` | `standard_distance(n)` |
| `new SeededPrng(s)`, `.NextDouble()`, `.Derive(l)` | `SeededPrng(s)`, `next_double!(p)`, `derive(p, l)` |
| `Correlithm.Random(p, n)`, `a.DistanceTo(b)` | `random_correlithm(p, n)`, `distance(a, b)` |
| `StringCo.Ring(p, n).At(t)` | `at(ring_co(p, n), t)` |
| `converter.Convert(v)`, `.Missing` | `topoint(converter, v)`, `missingpoint(converter)` |
| `new PatternMiner().Mine(points)` | `mine(PatternMiner(), points)` |
| `new RuleMiner().Mine(s, ps, t, pt)` | `mine(RuleMiner(), s, ps, t, pt)` |
| `new Cue().Find(rules, plies)` | `find_hits(Cue(), rules, plies)` |
| `Bench.HoldoutRecall(...)` | `holdout_recall(...)` (`r.recall`, `r.precision`) |
| `IEqualityComparer` / `IComparer` | `key = f` / `lt = f` keywords |
| `ArgumentException` / `ArgumentOutOfRangeException` | `ArgumentError` / `DomainError` |

## Build and test

```
julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'
julia --project=. -e 'using Pkg; Pkg.test()'
```

or from the repo root: `pwsh ./build.ps1 -Profile Julia -Test`. The tests port every C# test
(including the COR-T4 and COR-T5 invariants), check every section of `conformance/vectors.json`, and
assert the package has no dependencies. Requires Julia 1.9 or later.
