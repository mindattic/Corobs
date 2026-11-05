# Corobs for TypeScript

`@mindattic/corobs` is the TypeScript port of [Corobs](../README.md), Correlithm Object technology
after P. Nick Lawrence's *Correlithm Object Technology* (2004). It runs in Node 18+ and in browsers,
has no runtime dependencies, and reproduces the C# reference implementation **bit for bit** under the
same seed: its conformance test checks every value in [`conformance/vectors.json`](../conformance/README.md).

## Install

```
npm install @mindattic/corobs
```

ES module only. Subpath exports mirror the namespaces: `@mindattic/corobs/geometry`, `/seeding`,
`/strings`, `/converters`, `/mining`, `/bench`.

## Example

```ts
import { CardinalConverter, ContinuousConverter, Correlithm, Cue, NCube, PatternMiner, RuleMiner, SeededPrng } from "@mindattic/corobs";

const root = new SeededPrng(2004n);             // signed 64-bit seed: bigint, or a safe-integer number
const faction = new CardinalConverter<string>(root.derive("faction"), 64);
const age = new ContinuousConverter(root.derive("age"), 64, 0, 120);

const a = faction.convert("Underclan");
const b = faction.convert("Arcturus");
console.log(a.distanceTo(b), NCube.standardDistance(64));     // ≈ μ = √(64/6): strangers
console.log(NCube.bitContent(64, age.convert(30).distanceTo(age.convert(31))));  // close ages carry bits
console.log(age.convert(null).equals(Correlithm.midpoint(64)));                  // missing → midpoint

// Mining: plies of { id, point }, patterns per ply, rules between plies, cues ranked by bits.
const miner = new PatternMiner();               // 6σ links, ≥ 5 members
// const rules = new RuleMiner(0.8).mine("faction", miner.mine(f), "turf", miner.mine(t));
// const hits = new Cue().find(rules, new Map([["faction", fMap], ["turf", tMap]]));
```

The API follows the C# reference in TypeScript idiom: camelCase members, `null`/`undefined` for a
missing value, `bigint` for 64-bit words and seeds, and functions instead of .NET comparers (a
`Compare<TId>` for order, a `KeyOf<TId>` for equality). Errors are `ArgumentError`,
`ArgumentOutOfRangeError` (a subclass) and `InvalidOperationError`.

`CardinalConverter` keys values with `String(value)` by default. Integers and strings print the same
in every language; pass an explicit key for other values when points must match another port.

## Build and test

```
npm ci
npm run build       # tsc → dist/
npm run typecheck   # src and tests
npm test            # vitest run
```

or from the repository root: `pwsh ./build.ps1 -Profile TypeScript -Test`.
