import { readFileSync } from "node:fs";
import { expect } from "vitest";
import { Correlithm, SeededPrng } from "../src/index.js";

/** The C# reference's vectors (conformance/README.md documents the schema). */
export const vectors: any = JSON.parse(readFileSync(new URL("../../conformance/vectors.json", import.meta.url), "utf8"));

const dv = new DataView(new ArrayBuffer(8));

/** The IEEE-754 bits of a double as 16 lowercase hex digits. */
export function bits(x: number): string {
  dv.setFloat64(0, x);
  return dv.getBigUint64(0).toString(16).padStart(16, "0");
}

/** The double whose IEEE-754 bits are these 16 hex digits. */
export function fromBits(hex: string): number {
  dv.setBigUint64(0, BigInt("0x" + hex));
  return dv.getFloat64(0);
}

export const pointBits = (p: Correlithm): string[] => p.coordinates.map(bits);

/** Relative error ≤ 1e-12, absolute ≤ 1e-300 near zero, as conformance/README.md specifies. */
export function expectClose(actual: number, expected: number, what = ""): void {
  if (actual === expected) return;
  const err = Math.abs(actual - expected);
  expect(err <= 1e-12 * Math.abs(expected) || err <= 1e-300, `${what}: ${actual} vs ${expected}`).toBe(true);
}

/** |actual − expected| ≤ tolerance (NUnit's Is.EqualTo(x).Within(t)). */
export function expectWithin(actual: number, expected: number, tolerance: number, what = ""): void {
  expect(Math.abs(actual - expected), `${what}: ${actual} vs ${expected} ± ${tolerance}`).toBeLessThanOrEqual(tolerance);
}

export const mean = (xs: readonly number[]): number => xs.reduce((s, x) => s + x, 0) / xs.length;

/** A point within ±jitter of `centre` in every coordinate, clamped to the cube. */
export function near(centre: Correlithm, prng: SeededPrng, jitter: number): Correlithm {
  const c = new Array<number>(centre.dimensions);
  for (let i = 0; i < c.length; i++) c[i] = Math.min(1, Math.max(0, centre.at(i) + (prng.nextDouble() - 0.5) * 2 * jitter));
  return new Correlithm(c);
}
