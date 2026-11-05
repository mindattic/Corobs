import { describe, expect, it } from "vitest";
import { Bench, roundHalfEven } from "../src/index.js";

describe("Bench", () => {
  it("holdout recall counts hidden pairs the predictor recovers", () => {
    const pairs: [string, string][] = [];
    for (let i = 0; i < 20; i++) pairs.push([`a${i}`, `b${i}`]);
    // A predictor that knows every pair recovers everything with perfect precision.
    const all = new Map<string, string[]>();
    for (const [a, b] of pairs) {
      all.set(a, [...(all.get(a) ?? []), b]);
      all.set(b, [...(all.get(b) ?? []), a]);
    }
    const perfect = Bench.holdoutRecall(pairs, 0.25, 1, (id) => all.get(id) ?? []);
    expect(perfect.hidden).toBe(5);
    expect(perfect.recall).toBe(1);
    expect(perfect.precision).toBe(1);
    // A predictor that knows nothing recovers nothing.
    const blind = Bench.holdoutRecall(pairs, 0.25, 1, () => []);
    expect(blind.recall).toBe(0);
    // Same seed, same hidden set.
    expect(Bench.holdoutRecall(pairs, 0.25, 1, () => []).hidden).toBe(blind.hidden);
  });

  it("reach counts hops and isolated records", () => {
    const adj = new Map<number, number[]>([
      [1, [2]],
      [2, [1, 3]],
      [3, [2]],
      [4, []],
    ]);
    const r = Bench.reach([1, 2, 3, 4], (id) => adj.get(id)!, 2);
    expect(r.isolated).toBe(1);
    expect(r.total).toBe(4);
    expect(r.meanReachableByHop[0]).toBe((1 + 2 + 1 + 0) / 4);
    expect(r.meanReachableByHop[1]).toBe((2 + 2 + 2 + 0) / 4);
  });

  it("cascade yield is closed by cascade per direct fix", () => {
    expect(Bench.cascadeYield(6, 4)).toBe(1.5);
    expect(Bench.cascadeYield(0, 0)).toBe(0);
  });

  it("rounds half to even like C# Math.Round", () => {
    expect([0.5, 1.5, 2.5, 10.5, 11.5, 2.4, 2.6].map(roundHalfEven)).toEqual([0, 2, 2, 10, 12, 2, 3]);
  });
});
