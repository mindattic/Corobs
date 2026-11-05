import { describe, expect, it } from "vitest";
import { ArgumentError, Correlithm, Cue, NCube, PatternMiner, RuleMiner, SeededPrng, type PlyPoint } from "../src/index.js";
import { expectWithin, near } from "./helpers.js";

describe("Mining", () => {
  const N = 64;

  it("a planted cluster among random points is the only pattern", () => {
    const prng = new SeededPrng(100);
    const points: PlyPoint<number>[] = [];
    for (let i = 0; i < 1000; i++) points.push({ id: i, point: Correlithm.random(prng, N) });
    const centre = Correlithm.random(prng, N);
    for (let i = 1000; i < 1006; i++) points.push({ id: i, point: near(centre, prng, 0.05) });

    const patterns = new PatternMiner(6, 5).mine(points);

    expect(patterns).toHaveLength(1);
    expect([...patterns[0]!.members].sort((a, b) => a - b)).toEqual([1000, 1001, 1002, 1003, 1004, 1005]);
    expect(patterns[0]!.bits).toBeGreaterThan(NCube.bitContent(N, NCube.distanceAtDeviations(N, 6)));
    expect(patterns[0]!.radius).toBeLessThan(patterns[0]!.meanPairDistance);
  });

  it("random points alone yield no pattern", () => {
    const prng = new SeededPrng(101);
    const points = Array.from({ length: 1500 }, (_, i) => ({ id: i, point: Correlithm.random(prng, N) }));
    expect(new PatternMiner().mine(points)).toEqual([]);
  });

  it("mining is deterministic", () => {
    const make = (): PlyPoint<number>[] => {
      const p = new SeededPrng(102);
      return Array.from({ length: 300 }, (_, i) => ({ id: i, point: i < 8 ? near(Correlithm.midpoint(N), p, 0.05) : Correlithm.random(p, N) }));
    };
    const a = new PatternMiner().mine(make());
    const b = new PatternMiner().mine(make());
    expect(a.map((p) => p.members)).toEqual(b.map((p) => p.members));
    expect(a.map((p) => p.bits)).toEqual(b.map((p) => p.bits));
  });

  it("a rule emerges and the one member that breaks it is the top hit", () => {
    const prng = new SeededPrng(103);
    const cs = Correlithm.random(prng, N); // where the faction sits on ply s
    const ct = Correlithm.random(prng, N); // where its turf sits on ply t

    const s: PlyPoint<number>[] = [];
    const t: PlyPoint<number>[] = [];
    for (let id = 1; id <= 10; id++) s.push({ id, point: near(cs, prng, 0.05) }); // ten members of one faction
    for (let id = 1; id <= 9; id++) t.push({ id, point: near(ct, prng, 0.05) }); // nine share the turf
    t.push({ id: 10, point: Correlithm.random(prng, N) }); // one lives somewhere unrelated
    for (let id = 11; id <= 40; id++) {
      s.push({ id, point: Correlithm.random(prng, N) });
      t.push({ id, point: Correlithm.random(prng, N) });
    }

    const miner = new PatternMiner();
    const ps = miner.mine(s);
    const pt = miner.mine(t);
    expect(ps).toHaveLength(1);
    expect(pt).toHaveLength(1);

    const rules = new RuleMiner(0.8).mine("faction", ps, "turf", pt);
    expect(rules).toHaveLength(1);
    expectWithin(rules[0]!.support, 0.9, 1e-9);

    const plies = new Map([
      ["faction", new Map(s.map((p) => [p.id, p.point] as const))],
      ["turf", new Map(t.map((p) => [p.id, p.point] as const))],
    ]);
    const hits = new Cue().find(rules, plies);
    expect(hits).toHaveLength(1);
    expect(hits[0]!.id).toBe(10);
    expect(hits[0]!.rank).toBe(1);
    expect(hits[0]!.bits).toBeGreaterThan(0);
    expect(hits[0]!.targetDistance).toBeGreaterThan(NCube.distanceAtDeviations(N, 1));
  });

  it("a rule needs support", () => {
    const prng = new SeededPrng(104);
    const cs = Correlithm.random(prng, N);
    const ct = Correlithm.random(prng, N);
    const s = Array.from({ length: 10 }, (_, i) => ({ id: i + 1, point: near(cs, prng, 0.05) }));
    const t = [
      ...Array.from({ length: 5 }, (_, i) => ({ id: i + 1, point: near(ct, prng, 0.05) })),
      ...Array.from({ length: 5 }, (_, i) => ({ id: i + 6, point: Correlithm.random(prng, N) })),
    ];
    const miner = new PatternMiner();
    expect(new RuleMiner(0.8).mine("a", miner.mine(s), "b", miner.mine(t)), "half the members is not a rule").toEqual([]);
    expect(() => new RuleMiner().mine("a", miner.mine(s), "a", miner.mine(t))).toThrow(ArgumentError);
  });

  it("a cue without a ply's points is an argument error", () => {
    const prng = new SeededPrng(105);
    const c = Correlithm.random(prng, N);
    const pts = Array.from({ length: 6 }, (_, i) => ({ id: i, point: near(c, prng, 0.05) }));
    const pattern = new PatternMiner().mine(pts);
    const rules = new RuleMiner().mine("a", pattern, "b", pattern);
    expect(() => new Cue().find(rules, new Map())).toThrow(ArgumentError);
  });
});
