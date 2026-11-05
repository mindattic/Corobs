import { describe, expect, it } from "vitest";
import { ArgumentOutOfRangeError, SeededPrng } from "../src/index.js";
import { expectWithin, mean } from "./helpers.js";

describe("SeededPrng", () => {
  it("same seed, same stream", () => {
    const a = new SeededPrng(42);
    const b = new SeededPrng(42);
    for (let i = 0; i < 1000; i++) expect(a.nextUInt64()).toBe(b.nextUInt64());
  });

  it("different seeds differ", () => {
    const a = new SeededPrng(1);
    const b = new SeededPrng(2);
    const xs = Array.from({ length: 16 }, () => a.nextUInt64());
    const ys = Array.from({ length: 16 }, () => b.nextUInt64());
    expect(xs).not.toEqual(ys);
  });

  it("doubles are uniform on the unit interval", () => {
    const p = new SeededPrng(99);
    const xs = Array.from({ length: 20000 }, () => p.nextDouble());
    for (const x of xs) {
      expect(x).toBeGreaterThanOrEqual(0);
      expect(x).toBeLessThan(1);
    }
    expectWithin(mean(xs), 0.5, 0.01);
  });

  it("derive is deterministic and independent of consumption", () => {
    const a = new SeededPrng(5);
    a.nextUInt64();
    a.nextUInt64();
    const b = new SeededPrng(5);
    expect(a.derive("faction").seed).toBe(b.derive("faction").seed);
    expect(a.derive("faction").seed).not.toBe(b.derive("turf").seed);
    expect(a.derive("faction").seed).not.toBe(a.seed);
  });

  it("a number seed and the same bigint seed give the same stream", () => {
    expect(new SeededPrng(-7).nextUInt64()).toBe(new SeededPrng(-7n).nextUInt64());
  });

  it("rejects seeds and bounds outside their ranges", () => {
    expect(() => new SeededPrng(1n << 63n)).toThrow(ArgumentOutOfRangeError);
    expect(() => new SeededPrng(0.5)).toThrow(ArgumentOutOfRangeError);
    expect(() => new SeededPrng(1).next(0)).toThrow(ArgumentOutOfRangeError);
  });
});
