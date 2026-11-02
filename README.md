# Corobs

**COROBS** — COrrelation + algoRithm OBjectS — is a pure, deterministic .NET implementation of
**Correlithm Object technology**, the computing paradigm discovered and developed by
**Dr. Patrick Nick Lawrence (P. Nick Lawrence, Ph.D.)** and set out in his book *Correlithm Object
Technology* (Correlithm Publications, a division of Lawrence Technologies, LLC, Dallas, 2004,
ISBN 0-9752761-1-5). Everything in this library follows that book; chapter, table and equation
numbers in the code and tests refer to it.

> *cor·re·lithm* n. [correlation + algorithm] 1 *Math.* any systematic method for solving problems
> by using similarities to known examples. 2 *Comput.* an algorithm primarily based on the use of
> characterizing examples. — Lawrence, who coined the term around 1975.

## The technology

**A point in a high-dimensional unit cube is a token.** Take a list of *N* numbers, each drawn at
random from [0, 1]. It is a point in a unit *N*-cube. Lawrence's central observation (Ch. II) is
that for *N* above about twenty, *any two such points are almost exactly the same distance apart*:
the expected distance — **standard distance** — is μ = √(N/6), and its standard deviation is
σ ≈ √(7/120) ≈ 0.2415, a constant that does **not** grow with *N* (Table II-1). At N = 100, two
random points lie 4.08 ± 0.24 apart; the chance that two of them land within 0.5 of each other is
about 10⁻⁶ (Eq. III-J).

**So proximity is information.** If a new point lands close to a known one, that did not happen by
accident: almost certainly the same process produced both, and the small gap is noise. A point
therefore stands for its datum not only at its exact coordinates but, to a degree that falls off
quadratically with distance, everywhere nearby — Lawrence calls this a **soft token** (Ch. IV). The
information in a proximity *d* is about ((μ − d)/σ)² / ln 2 ≈ 24.75·(μ − d)² bits (Eq. III-H); a
unit cube of 100 dimensions holds on the order of 10³³ usable tokens before two collide (Eq. III-Q).

**Rules map tokens to tokens.** A rule `s.p >: t.q` watches a subspace *s*: when its state comes near
pattern point *p*, the rule drives the state of subspace *t* correspondingly near pattern point *q*
(Ch. IV–V). Rules compose into pathways, trees, state machines and attractors; Lawrence shows the
model is logically and Turing complete (Ch. VI), and that it inherits properties no digital
representation has: **robustness** and **sampling** (a rule still works on a random subset of its
dimensions), **superposition** (one state point can carry several tokens at once), and a
statistically **holographic** character — a system "spread" over many cells degrades in resolution,
not in function, as cells are lost (Ch. VIII).

**Strings carry geometry.** A **string CO** (Ch. VII) embeds a line, a ring, a surface or any shape
into the cube so that distance along the shape becomes distance in the cube — rising from zero to
standard distance as positions move apart — while every position stays at standard distance from
anything unrelated. This is how order, time, quantity and position enter the space.

**Converters move world data in and out** (Ch. IX): *cardinal* sets (unordered categories) become
random tokens; *ordinal* sets (ranks, tiers) become evenly spaced positions on a string CO;
*continuous* values interpolate along one; higher dimensions use planar and volumetric strings; a
missing value sits at the cube's midpoint and carries no bits.

**What falls out** (Ch. X–XI): systems that "see and do things like things previously seen and
done"; graded rather than brittle matching; **cueing systems** that direct a human expert's attention
to the most productive places; **anomaly detection** — the rare event that is simply "not like the
others"; data fusion by superposition; and Lawrence's own forecast of ensembles beyond neurons,
including social ones: *"the ensemble is made up of individuals and the correlithm objects describe
social groupings and shared opinions."*

## What this library does

Corobs gives any catalog of things — characters, places, documents, sensors, people — a geometry.

| Namespace | Holds |
|---|---|
| `Corobs.Geometry` | `NCube` — μ, σ, bits, probability of proximity, point capacity (Table II-1, Eq. III-H/J/Q); `Correlithm` — a point CO with distance, centroid, superposition |
| `Corobs.Seeding` | `SeededPrng` — xoshiro256** under one seed; `Derive(label)` gives per-ply, per-value child streams so a space rebuilds bit-for-bit |
| `Corobs.Strings` | `StringCo` — line, ring and plane string COs built the way the book advises (random per-dimension breakpoints, no interpolation shortcuts) |
| `Corobs.Converters` | `IConverter<T>` with cardinal, ordinal, continuous (optionally wrapping) and planar converters; the midpoint for a missing value |
| `Corobs.Mining` | `PatternMiner` — clusters far tighter than chance (union-find at a σ threshold); `RuleMiner` — `s.p >: t.q` with support; `Cue` — ranked contradiction candidates: things inside a rule's source that miss its target |
| `Corobs.Bench` | hold-out recall, reach and cascade yield over abstract ids, for comparing this way against any other on the same ground truth |

**Pure.** No I/O, database, network or LLM client; a test asserts the library project references
nothing. **Deterministic.** Same seed, same inputs → identical coordinates, cluster ids and hit
ranks, on any machine. **Measurement, never judgment.** The library ranks and cues; confirming a
pattern, accepting a rule and resolving a hit are the caller's decisions, carried as ids.

### A worked shape

1. Pick plies (subspaces) for the facts you hold: *faction* (cardinal), *tier* (ordinal), *age*
   (continuous), *map position* (planar), *story-time* (continuous or ring).
2. Convert every thing's facts to a point per ply. Missing facts go to the midpoint.
3. `PatternMiner` finds, per ply, the groups whose points lie 6σ or more below standard distance —
   truths nobody wrote down ("everyone who frequents this place belongs to that faction").
4. `RuleMiner` proposes `s.p >: t.q` wherever most of a pattern's members share a pattern on another
   ply. A human confirms the ones that are true.
5. `Cue` ranks the members that satisfy a confirmed rule's source and miss its target. A human reads
   each, fixes the record or the source, and re-runs. Fixes cascade: the next build closes hits
   nobody touched.
6. `Bench` says whether this beat whatever you did before, on the same hidden ground truth.

## Consumers

- **Prose** (`mindattic/Prose`, RFC 0016) — the GLMZ fiction universe: ~14,000 entities become
  trajectories through story-time, shared incidents become time-scoped patterns their witnesses are
  pulled toward, an old-way-vs-COROBS bench, and a version grader for books, series and the universe.
  Prose keeps its own adapters (record → ply converters, storage, CLI, wiki) on its side of the line.

## Attribution and rights

Correlithm Object technology is the work of **Dr. Patrick Nick Lawrence**. The theory, the
terminology (correlithm, correlithm object, soft token, string CO, standard distance, ply, cell,
converter, sensor, actor, straddler, Synthorg®) and every result cited here are his, from
*Correlithm Object Technology* (2004). The book's preface records that the principal intellectual
property rights were held by Lawrence Technologies, LLC (www.LT.com), and that early applications
were funded in part by the United States Air Force (contracts F30602-02-C-0077 and F30602-03-C-0051).

This library is an independent implementation written from the published description; it is not
affiliated with, endorsed by, or derived from code of Lawrence Technologies, LLC. Synthorg® is their
trademark. If you build on this work, cite the book.

## Layout

```
Corobs/            the library (net9.0; net10.0, no references)
Corobs.Tests/      NUnit — the book's statistics checked against the cube, determinism, planted clusters
assets/            diagrams and other public assets
docs/              design notes
book/              (not in this repository) the maintainer's private reference copy of the book
```

### About the book

*Correlithm Object Technology* is copyrighted (© 2004 Lawrence Technologies, LLC) and is **not**
redistributed here. Maintainers keep a private reference copy in a separate private repository,
checked out at `book/` (git-ignored), so that every number in this library can be checked against
the page it came from. Buy the book; cite the book.

## House rules

MindAttic house rules apply (see `AGENTS.md`): every change is a ticket; commits name the ticket;
archive, never delete; whole-number versions once consumed.
