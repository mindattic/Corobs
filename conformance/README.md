# Conformance vectors

`vectors.json` is the C# reference implementation's exact output on a fixed set of inputs. Every
language port reads it in its own test suite and must reproduce it. It is generated, never edited:

```
pwsh ./build.ps1 -Profile Vectors      # Corobs.Csharp/Corobs.TestVectors writes conformance/vectors.json
```

The C# suite's `ConformanceTests` fails when the file is stale, so a change to the reference cannot
land without regenerating it; every port's conformance test then shows whether it still agrees.

## Encoding

| JSON shape | Meaning | How a port compares |
|---|---|---|
| 16 lowercase hex digits, a string (`"3fe0000000000000"`) | the IEEE-754 bits of a double | **exactly**, bit for bit (decode with the language's bits-to-double) |
| decimal string (`"-1"`, `"18446744073709551615"`) | a 64-bit integer: `seed`s are signed, `uint64`/`firstUint64` unsigned | exactly |
| JSON number | a statistic that passes through `log`, `pow` or a support ratio | relative error ≤ 1e-12 (absolute ≤ 1e-300 near zero) |
| array of hex strings | a point's coordinates, in dimension order | exactly |

Doubles that must be exact are never written as JSON numbers, because not every JSON parser rounds
decimals correctly. Inputs that may be infinite or NaN (`t`, `value`, `x`, `y`) are hex too.

## Sections

- **prng** — per seed: the first 8 `NextUInt64`, the first 8 `NextDouble` (bits) from a *fresh*
  stream each, and for each `max` the first 8 `Next(max)` from a fresh stream.
- **derive** — `new SeededPrng(seed).Derive(label)`: the child's seed, its first `NextUInt64`, and the
  child's own `Derive("x")` seed. Labels include the empty string and non-ASCII text (UTF-8 bytes).
- **ncube** — the three constants and, per N, every `NCube` function at a set of distances/bits/
  deviations. Distances in this section are JSON numbers (tolerance).
- **correlithm** — two `Random` points drawn in sequence from seed 7 at N = 8, the midpoint, their
  squared distance and distance (bits), the centroid of {a, b, midpoint} in that order, and
  `a.Interpolate(b, f)`.
- **strings** — `StringCo.Line`/`Ring`/`Plane` each from its own fresh seed at N = 16, sampled with
  `At(t)`, `AtIndex(i, count)` and `At(x, y)`.
- **converters** — cardinal (`ToString` keys, cache), ordinal, continuous on a line and on a ring, and
  planar, each from its own fresh seed at N = 16. A NaN/null/missing value, and ±∞ on a ring, gives
  `missing` (the midpoint).
- **mining** — 20 things (ids 1–20) on plies `faction` and `turf` at N = 64, given as explicit points.
  Expected `PatternMiner` output per ply (members in order, centroid, radius and mean pair distance as
  bits; `bits` with tolerance), `RuleMiner.Mine("faction", factionPatterns, "turf", turfPatterns)`
  (patterns referenced by index into those lists) and `Cue.Find` hits (rule referenced by index).
- **bench** — `HoldoutRecall` over the listed pairs with each predictor (neighbour lists given
  explicitly for ids 1–40; an id not listed has no neighbours), `Reach` and `CascadeYield`.

## Where languages quietly disagree

These are the traps that make a port "almost" right. Each one is exercised by the vectors.

1. **64-bit unsigned arithmetic wraps.** xoshiro256**, SplitMix64 and FNV-1a are all mod 2⁶⁴.
   Python and Julia `Int`/`BigInt` and JavaScript numbers do not wrap on their own: mask with
   `& 0xFFFFFFFFFFFFFFFF` (Python), use `UInt64` (Julia), use `BigInt` + `BigInt.asUintN(64, …)` or
   paired 32-bit halves (TypeScript). Java has no unsigned long: use `long` and `>>>`.
2. **The seed is signed; FNV hashes its 8 little-endian bytes,** then the label's **UTF-8** bytes
   (not UTF-16, not the platform encoding). `Derive` returns `new SeededPrng((long)hash)`; its seed
   is the hash reinterpreted as signed.
3. **`NextDouble` = `(x >> 11) * 2^-53`.** `Next(max)` = `(int)(NextDouble() * max)`, truncation.
4. **No fused multiply-add.** `a + (b − a)·f`, `x·dx + y·dy` and the squared-distance sum must round
   after every operation. C++: build with `/fp:precise` (MSVC) or `-ffp-contract=off` (GCC/Clang).
   Go may fuse `x*y + z` on some targets: write `float64(x*y) + z`. Never use `fma`, `@fastmath`,
   `muladd` or a vectorised sum that reorders the additions.
5. **Sums are left to right, in index order.** Centroid: accumulate each point in order, then divide
   each coordinate by the count. Mean pair distance: `a < b` double loop.
6. **`Math.Round` rounds half to even** (`Bench.HoldoutRecall` hides `round(count × fraction)`
   pairs: 21 × 0.5 → 10, not 11). Python's `round` already does; Java `Math.rint`, Rust
   `round_ties_even`, Go `math.RoundToEven`, Julia `round`, TypeScript needs its own.
7. **Pair canonical order compares the ids' decimal text ordinally** (`"10" < "9"`), as C#
   `string.CompareOrdinal(a.ToString(), b.ToString())` does. For non-ASCII ids that is UTF-16 code
   unit order.
8. **Ordering is stable.** Patterns: bits descending, then first member ascending. Rules: bits
   descending, ties in source-pattern order. Hits: bits descending, then id ascending; rank from 1.
   The union-find links the root with the smaller index as parent; groups are emitted in order of
   their first (sorted) member before the final sort.
9. **Ring phase** is `phase = t − o; phase −= floor(phase)`, written exactly like that (not `fmod`,
   not `%`, which differ for negative values and for large |t|).
10. **`sin`/`cos` for the plane** come from each runtime's libm and may differ in the last bit. A
    plane coordinate only flips if a projection lands within an ulp of its breakpoint, so the vectors
    are expected to match exactly; if one does not, report it rather than loosening the test.
