import { describe, expect, it } from "vitest";
import { ArgumentOutOfRangeError, Bench, ContinuousConverter, Correlithm, NCube, PatternMiner, SeededPrng, StringCo, type IdPair, type KeyOf } from "../src/index.js";

/** COR-T4 and COR-T5 (docs/BUGS.md). Each test asserts an invariant, not an implementation; the C#
 * reference keeps the old code behind its symbol, and these pass on the fixed behaviour ported here. */
describe("COR-T4", () => {
  it("threshold: no pattern member is linked by a pair short of the required σ", () => {
    const n = 4;
    const miner = new PatternMiner(6, 5);
    expect(NCube.distanceAtDeviations(n, miner.minDeviations), "precondition: μ − 6σ < 0 at N = 4").toBeLessThan(0);

    const points = Array.from({ length: 5 }, (_, k) => ({ id: k, point: new Correlithm([0.1 * k, 0.5, 0.5, 0.5]) }));

    for (const pattern of miner.mine(points))
      for (const id of pattern.members) {
        const p = points[id]!.point;
        const best = Math.max(...pattern.members.filter((o) => o !== id).map((o) => NCube.deviationsBelow(n, p.distanceTo(points[o]!.point))));
        expect(best, `member ${id} joined a ${miner.minDeviations}σ pattern though its closest partner is only ${best.toFixed(2)}σ below μ`).toBeGreaterThanOrEqual(miner.minDeviations);
      }
  });

  it.each([Number.POSITIVE_INFINITY, Number.NEGATIVE_INFINITY])("ring at(%s) never returns a point off the ring", (t) => {
    const n = 32;
    const ring = StringCo.ring(new SeededPrng(42), n);

    let p: Correlithm;
    try {
      p = ring.at(t);
    } catch (e) {
      expect(e).toBeInstanceOf(ArgumentOutOfRangeError);
      return;
    }

    // A ring takes exactly 2N distinct points, one per arc between its 2N breakpoints.
    const key = (c: Correlithm): string => c.coordinates.join(",");
    const onRing = new Set<string>();
    const steps = 200_000;
    for (let k = 0; k < steps; k++) onRing.add(key(ring.at(k / steps)));
    expect(onRing.size, "precondition: the grid visits every ring point").toBe(2 * n);
    expect(onRing.has(key(p)), `at(${t}) returned a point the ring never visits (book Ch. IX, p. 123: exactly on the string)`).toBe(true);
  });

  function oracle<T>(pairs: readonly IdPair<T>[], key: KeyOf<T>): (id: T) => T[] {
    const map = new Map<unknown, T[]>();
    for (const [a, b] of pairs) {
      map.set(key(a), [...(map.get(key(a)) ?? []), b]);
      map.set(key(b), [...(map.get(key(b)) ?? []), a]);
    }
    return (id) => map.get(key(id)) ?? [];
  }

  it("pairs: a perfect predictor recovers every hidden relationship even when listed repeatedly", () => {
    const pairs: [number, number][] = [];
    for (let i = 0; i < 20; i++) pairs.push([2 * i, 2 * i + 1], [2 * i, 2 * i + 1], [2 * i + 1, 2 * i]);
    const r = Bench.holdoutRecall(pairs, 0.5, 7, oracle(pairs, (x) => x));
    expect(r.recall, `perfect predictor scored recall ${r.recall.toFixed(3)} (hidden ${r.hidden}, recovered ${r.recovered})`).toBe(1);
  });

  it("pairs: one relationship under the caller's comparer is hidden once", () => {
    const ignoreCase: KeyOf<string> = (s) => s.toUpperCase();
    const pairs: [string, string][] = [];
    for (let i = 0; i < 20; i++) pairs.push([`a${i}`, `B${i}`], [`b${i}`, `A${i}`]);
    const r = Bench.holdoutRecall(pairs, 0.5, 7, oracle(pairs, ignoreCase), ignoreCase);
    expect(r.hidden, "20 relationships, half hidden; each spelled two ways is still one relationship").toBe(10);
  });
});

describe("COR-T5 (a decision, docs/BUGS.md)", () => {
  it.each([Number.POSITIVE_INFINITY, Number.NEGATIVE_INFINITY])("a wrapping converter maps %s to missing", (value) => {
    const hours = new ContinuousConverter(new SeededPrng(1), 32, 0, 24, true);
    expect(hours.convert(value).equals(hours.missing)).toBe(true);
  });
});
