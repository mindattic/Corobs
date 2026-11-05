# Bug ledger

Corobs implements Lawrence's *Correlithm Object Technology* (2004) and is otherwise left alone. When a
defect is fixed, the old code stays in the source behind a compiler symbol, a test in
`Corobs.Csharp/Corobs.Tests/Bugs/` checks an invariant the old code breaks, and the proof is recorded here. Page
numbers are the book's printed pages, checked against the PDF.

Each entry is one of:

- **Book divergence**: the code contradicted the book.
- **Implementation defect**: the book is right and silent; the code broke its own definition or plain mathematics.
- **Decision**: no proof exists either way; the behaviour was chosen, and the owner may revert it.

## Reproducing the old behaviour

```
dotnet test Corobs.Csharp/Corobs.Tests                           # fixed code: all pass
dotnet test Corobs.Csharp/Corobs.Tests -p:CorobsBugs=COROBS_BUG_COR_T4_RING   # old code: that fix's tests fail
```

`CorobsBugs` takes any symbol below (several at once as `A%3BB`). Shipping the old behaviour means
building the package with the same property, which is how a fix is reverted without editing source.

| Symbol | Ticket | Where | Kind | Test |
|---|---|---|---|---|
| `COROBS_BUG_COR_T4_THRESHOLD` | COR-T4 | `PatternMiner.Mine` | implementation defect | `COR_T4Tests.Threshold_*` |
| `COROBS_BUG_COR_T4_RING` | COR-T4 | `StringCo.At(double)` | book divergence | `COR_T4Tests.Ring_*` |
| `COROBS_BUG_COR_T4_PAIRS` | COR-T4 | `Bench.HoldoutRecall` | implementation defect | `COR_T4Tests.Pairs_*` |
| `COROBS_BUG_COR_T5` | COR-T5 | `ContinuousConverter.Convert` | decision | `COR_T5Tests.Decision_*` |

---

## COR-T4 · THRESHOLD: a negative linking threshold linked points

**Kind:** implementation defect. The book is right.

**Definition.** `PatternMiner` links two points when ‖p − q‖ ≤ d\*, where d\* = μ − kσ, μ = √(N/6)
and σ ≈ 0.2415 (Table II-1). This is the book's own construction: on p. 36 Lawrence computes the
6σ distance at N = 20 as (7.56 − 6.0) × 0.2415 ≈ 0.38.

**Claim.** If d\* < 0, no pair is linked.

**Proof.** A distance is never negative: ‖p − q‖ ≥ 0 > d\*. ∎

**The old code** tested ‖p − q‖² ≤ d\*². For d\* < 0, d\*² = |d\*|², so it linked every pair within
|d\*|. That is the threshold reflected about zero.

**Counterexample (the test).** At N = 4, μ = 0.8165 and d\* = 0.8165 − 6(0.2415) = −0.633. Five points
0.1 apart in a line were linked into a "6σ" pattern. The closest partner of point 0 lies only
(0.8165 − 0.1)/0.2415 = 2.97σ below μ, which the failing test reports. By Eq. III-H that proximity is
worth 2.97²/ln 2 ≈ 12.7 bits, not the ≥ 6²/ln 2 ≈ 51.9 bits a 6σ link certifies.

**When it occurs.** d\* < 0 ⇔ N < 6(kσ)². At k = 6 that is N ≤ 12, below the book's rule of thumb of
N ≥ ~20 (p. 36). The book allows small N "carefully", so the library accepts it, and must then answer
correctly.

## COR-T4 · RING: `StringCo.At(±∞)` on a ring returned a point off the ring

**Kind:** book divergence.

**The book.** A continuous sensor's state point is "not 'near' the string CO, but exactly on it"
(Ch. IX, p. 123).

**Construction.** Ring coordinate i at position t is aᵢ when frac(t − oᵢ) < ½, else bᵢ, with
breakpoints oᵢ uniform on [0, 1).

**The old code at t = ±∞.** Under IEEE-754, ±∞ − oᵢ = ±∞ and ±∞ − ⌊±∞⌋ = NaN, and `NaN < 0.5` is
false. So every coordinate became bᵢ, giving the point B = (b₁, …, b_N).

**Claim.** B is not on the ring, except with probability N / 2^(N−1).

**Proof.** B is on the ring iff some t has frac(t − oᵢ) ∈ [½, 1) for every i, i.e. iff the N arcs
[oᵢ + ½, oᵢ + 1) share a point. Arcs of length ½ share a point iff their N uniform start points lie
within one half-circle. By Wendel's theorem (1962) that happens with probability N / 2^(N−1):
1.5 × 10⁻⁸ at N = 32 and 6.9 × 10⁻¹⁸ at N = 64. So the old code answered ±∞ with a point that no
position on the ring produces, which contradicts p. 123. ∎

**The test** settles it exactly for its own ring rather than in probability. A ring takes exactly 2N
distinct points, one per arc between its 2N breakpoints (adjacent arcs differ in one coordinate). The
test visits all 2N, asserting that it found that many, and the old point is not among them.

**The fix** refuses ±∞ (`ArgumentOutOfRangeException`). A ring has no position there.

## COR-T4 · PAIRS: `HoldoutRecall` counted listings, not relationships

**Kind:** implementation defect. `Bench` is not in the book. This is measured against the definition
of recall.

**Definition.** A relationship is an unordered pair under the caller's equality comparer. Recall =
hidden relationships recovered ÷ hidden relationships. A perfect predictor, which returns every true
neighbour, recovers everything hidden, so its recall is 1 by definition.

**Defect 1: repeats.** The old code shuffled and hid list entries. A relationship listed m times could
be hidden up to m times, but it can be recovered only once.
- Counterexample (the test): 20 relationships, each listed three times (60 entries), half hidden.
  The old code hid 30 entries but only 18 distinct relationships, so the perfect predictor scored
  18/30 = 0.600.
- Contradiction: the perfect predictor's recall must be 1. ∎

**Defect 2: order and spelling.** Pairs were put in canonical order by `ToString()` and then compared
in order, which disagrees with the caller's comparer.
- Under `OrdinalIgnoreCase`, ("a", "B") becomes ("B", "a") and ("b", "A") becomes ("A", "b"). The
  ordered comparison calls them different, though they are one unordered pair.
- Counterexample (the test): 20 relationships, each spelled two ways, half hidden. The definition
  gives 10 hidden; the old code gave 20.

**The fix** de-duplicates relationships before shuffling. Pair equality is now unordered. The hash is
symmetric (XOR), as the `IEqualityComparer` contract requires once equality is unordered: equal pairs
must hash equal.

## COR-T5 · wrapping `ContinuousConverter` maps ±∞ to `Missing`

**Kind:** decision. This is not a proven error.

**What the book says.** A continuous converter takes "a floating-point variable in some bounded range"
(p. 123). It says nothing about values outside that range. It also says nothing about missing values:
mapping them to the midpoint is this library's choice, made from the Ch. II geometry, not a rule in
Ch. IX.

**Before:** a wrapping converter threw for ±∞, through the ring's guard. **After:** it returns
`Missing`, as it does for NaN. The open (line) converter clamps ±∞ to its ends; that is not from the
book either.

No mathematical argument makes either behaviour wrong. The test pins the current choice, so the
symbol build shows exactly what reverting it changes.
