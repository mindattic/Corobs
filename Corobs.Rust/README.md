# Corobs for Rust

The Rust port of [Corobs](../README.md): Correlithm Object technology (Lawrence, *Correlithm Object
Technology*, 2004) as a pure, deterministic library with **no dependencies**. Under the same seed it
reproduces the C# reference implementation bit for bit, checked against
[`conformance/vectors.json`](../conformance/README.md).

## Use

```toml
[dependencies]
corobs = { path = "../Corobs.Rust" }
```

```rust
use std::collections::HashMap;
use corobs::{CardinalConverter, Converter, Cue, PatternMiner, PlyPoint, RuleMiner, SeededPrng};

let root = SeededPrng::new(2004);
let mut faction = CardinalConverter::<str>::new(&root.derive("faction"), 64)?;
let mut turf = CardinalConverter::<str>::new(&root.derive("turf"), 64)?;

// One point per thing per ply; a missing fact goes to the midpoint (`convert(None)`).
let things = [(1, "Underclan", "Docks"), (2, "Underclan", "Docks") /* … */];
let s: Vec<PlyPoint<i32>> = things.iter().map(|&(id, f, _)| PlyPoint::new(id, faction.convert(Some(f)).unwrap())).collect();
let t: Vec<PlyPoint<i32>> = things.iter().map(|&(id, _, p)| PlyPoint::new(id, turf.convert(Some(p)).unwrap())).collect();

let miner = PatternMiner::default();                        // 6σ links, at least 5 members
let rules = RuleMiner::default().mine("faction", &miner.mine(&s)?, "turf", &miner.mine(&t)?)?;
let plies = HashMap::from([
    ("faction".to_string(), s.iter().map(|p| (p.id, p.point.clone())).collect()),
    ("turf".to_string(), t.iter().map(|p| (p.id, p.point.clone())).collect()),
]);
for hit in Cue::default().find(&rules, &plies)? {
    println!("{hit}");                                      // ranked: look at these first
}
# Ok::<(), corobs::CorobsError>(())
```

| Module | Holds |
|---|---|
| `geometry` | `ncube` (μ, σ, bits, probability, capacity: Table II-1, Eq. III-H/J/Q) and `Correlithm` |
| `seeding` | `SeededPrng`: xoshiro256** under one seed; `derive(label)` for child streams |
| `strings` | `StringCo`: line, ring and plane string COs (Ch. VII) |
| `converters` | the `Converter` trait; cardinal, ordinal, continuous (optionally wrapping) and planar |
| `mining` | `PatternMiner`, `RuleMiner`, `Cue` |
| `bench` | `holdout_recall`, `reach`, `cascade_yield` |

Calls that the C# reference refuses with an exception return `Err(CorobsError)` here, with the same
three kinds (`ArgumentOutOfRange`, `Argument`, `InvalidOperation`). `distance_to` panics on points
of different dimensionality; `try_distance_to` returns the error instead.

## Build and test

```
cargo build --all-targets
cargo clippy --all-targets -- -D warnings
cargo test
```

or from the repository root, `pwsh ./build.ps1 -Profile Rust -Test`. The tests port every C# test
(including the COR-T4 and COR-T5 invariants), check `conformance/vectors.json` section by section,
and assert that `[dependencies]` stays empty.

This port carries the fixed behaviour only; the old code of each catalogued bug lives in the C#
reference behind its `COROBS_BUG_*` symbol (see [docs/BUGS.md](../docs/BUGS.md)).
