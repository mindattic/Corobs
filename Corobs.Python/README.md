# Corobs for Python

A port of the C# reference implementation of Correlithm Object technology (Lawrence, *Correlithm
Object Technology*, 2004). Pure Python (3.10+), no runtime dependencies, and **bit-for-bit
identical** to the reference under the same seed, as proved by `tests/test_conformance.py` against
[`conformance/vectors.json`](../conformance/README.md). See the [repository README](../README.md) for
the technology.

## Install

```
pip install ./Corobs.Python            # or: pip install -e "./Corobs.Python[test]"
```

## Use

```python
from corobs import (CardinalConverter, ContinuousConverter, Cue, PatternMiner, PlyPoint,
                    RuleMiner, SeededPrng)

root = SeededPrng(2004)
faction = CardinalConverter(root.derive("faction"), 64)
age = ContinuousConverter(root.derive("age"), 64, 0, 120)

people = {1: ("Underclan", 31.0), 2: ("Underclan", 33.0), 3: ("Arcturus", None)}
plies = {
    "faction": {pid: faction.convert(f) for pid, (f, _) in people.items()},
    "age": {pid: age.convert(a) for pid, (_, a) in people.items()},   # None -> the midpoint
}

miner = PatternMiner(min_deviations=6, min_members=2)
patterns = {name: miner.mine([PlyPoint(i, p) for i, p in ply.items()]) for name, ply in plies.items()}
rules = RuleMiner(0.8).mine("faction", patterns["faction"], "age", patterns["age"])
for hit in Cue().find(rules, plies):   # ranked contradictions for a human to read
    print(hit)
```

API: `NCube`, `Correlithm` (geometry); `SeededPrng`; `StringCo.line/ring/plane` with `at`,
`at_xy`, `at_index`; `CardinalConverter`, `OrdinalConverter`, `ContinuousConverter`,
`PlanarConverter`; `PatternMiner`, `RuleMiner`, `Cue`; `holdout_recall`, `reach`, `cascade_yield`.
C# comparers become `key` (equality) and `order` (sort key) callables.

## Test

```
cd Corobs.Python
python -m pytest -q          # or, from the repo root: pwsh ./build.ps1 -Profile Python -Test
```
