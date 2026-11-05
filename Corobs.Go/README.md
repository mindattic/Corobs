# Corobs for Go

The Go port of [Corobs](../README.md): Correlithm Object technology from Dr. P. Nick Lawrence's
*Correlithm Object Technology* (2004), pure and deterministic. It reproduces the C# reference
(`Corobs.Csharp`) bit for bit under the same seed, checked against
[`conformance/vectors.json`](../conformance/README.md). No third-party modules.

```
go get github.com/mindattic/Corobs/Corobs.Go
```

| Package | Holds |
|---|---|
| `corobs` (root) | the sentinel errors `ErrOutOfRange`, `ErrArgument`, `ErrInvalidOperation` |
| `seeding` | `SeededPrng`: xoshiro256** under one seed; `Derive(label)` child streams |
| `geometry` | `NCube` statistics (Table II-1, Eq. III-H/J/Q) as functions; `Correlithm` points |
| `strco` | string COs: `Line`, `Ring`, `Plane` (Ch. VII) |
| `converters` | `Cardinal`, `Ordinal`, `Continuous`, `Planar`; `nil` converts to the midpoint |
| `mining` | `Mine`, `MineRules`, `Find`: patterns, rules `s.p >: t.q`, ranked cues |
| `bench` | `HoldoutRecall`, `Reach`, `CascadeYield` |

The string package is `strco`, not `strings`: a package named `strings` would shadow the standard
library's in every file that used both.

## Example

```go
package main

import (
	"fmt"

	"github.com/mindattic/Corobs/Corobs.Go/converters"
	"github.com/mindattic/Corobs/Corobs.Go/geometry"
	"github.com/mindattic/Corobs/Corobs.Go/mining"
	"github.com/mindattic/Corobs/Corobs.Go/seeding"
)

func main() {
	root := seeding.New(2004)
	faction := converters.NewCardinal[string](root.Derive("faction"), 64, nil)
	age, _ := converters.NewContinuous(root.Derive("age"), 64, 0, 120, false)

	under, arc := "Underclan", "Arcturus"
	a, _ := faction.Convert(&under)
	b, _ := faction.Convert(&arc)
	fmt.Printf("strangers: %.2f of mu\n", a.DistanceTo(b)/geometry.StandardDistance(64))

	thirty, thirtyOne := 30.0, 31.0
	x, _ := age.Convert(&thirty)
	y, _ := age.Convert(&thirtyOne)
	fmt.Printf("neighbours: %.1f bits\n", geometry.BitContent(64, x.DistanceTo(y)))

	var points []mining.PlyPoint[int]
	for id := 0; id < 200; id++ {
		points = append(points, mining.PlyPoint[int]{ID: id, Point: geometry.Random(root, 64)})
	}
	fmt.Println(len(mining.Mine(mining.DefaultPatternMiner(), points)), "patterns among random points")
}
```

## Errors and panics

Every refusal the C# reference throws is a returned error wrapping one of the root sentinels
(`errors.Is(err, corobs.ErrArgument)`), with two exceptions that panic, as `make` does with a
negative length: a non-positive dimension count, and measuring between points of different
dimensionality.

Go methods cannot take type parameters, so the generic operations are functions: `mining.Mine`,
`mining.MineRules`, `mining.Find`, `bench.HoldoutRecall`, `bench.Reach`. Each has a `...Func`
variant taking the caller's order (`compare`, as `slices.SortFunc` does) or equality (`key`), the
counterparts of C#'s `IComparer`/`IEqualityComparer`. By default ids are ordered by `cmp.Compare`
and equal under `==`; a cardinal value's key is `fmt.Sprint(v)`.

## Determinism notes

- Every product that feeds an addition is wrapped in `float64(...)`, so the compiler may not fuse
  it into a multiply-add on any architecture (the Go spec allows fusion otherwise).
- `bench` puts pairs in the reference's canonical order by comparing the ids' `fmt.Sprint` text as
  UTF-16 code units, exactly as C# `string.CompareOrdinal(a.ToString(), b.ToString())` does, and
  rounds the hidden count half to even (`math.RoundToEven`).
- `Derive` hashes the label's bytes, which for Go source text are its UTF-8 encoding.

## Build and test

```
go build ./...
go vet ./...
go test ./...
```

or, from the repository root, `pwsh ./build.ps1 -Profile Go -Test`.
