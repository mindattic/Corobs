import { describe, expect, it } from "vitest";
import { Correlithm, InvalidOperationError, NCube, SeededPrng, StringCo } from "../src/index.js";
import { expectWithin } from "./helpers.js";

/** Ch. VII: distance along the geometry becomes distance in the cube; strangers stay at μ. */
describe("StringCo", () => {
  const N = 2048; // large so a single string's statistics are tight

  it("line distance grows as root of separation and reaches μ", () => {
    const line = StringCo.line(new SeededPrng(11), N);
    const mu = NCube.standardDistance(N);
    const origin = line.at(0);
    const d1 = origin.distanceTo(line.at(0.1));
    const d3 = origin.distanceTo(line.at(0.3));
    const d6 = origin.distanceTo(line.at(0.6));
    const d10 = origin.distanceTo(line.at(1.0));
    expect(d1).toBeLessThan(d3);
    expect(d1).toBeLessThan(d6);
    expect(d3).toBeLessThan(d6);
    expect(d6).toBeLessThan(d10);
    expectWithin(d1 / mu, Math.sqrt(0.1), 0.06, "≈ μ·√|Δt|");
    expectWithin(d10 / mu, 1, 0.06, "the far ends are at standard distance");
    expect(origin.distanceTo(origin)).toBe(0);
  });

  it("ring wraps", () => {
    const ring = StringCo.ring(new SeededPrng(12), N);
    const mu = NCube.standardDistance(N);
    const origin = ring.at(0);
    expectWithin(origin.distanceTo(ring.at(0.5)) / mu, 1, 0.06, "opposite side is μ");
    expect(origin.distanceTo(ring.at(0.98)), "0.98 is next to 0").toBeLessThan(origin.distanceTo(ring.at(0.25)));
    expect(ring.at(0.3).distanceTo(ring.at(1.3)), "t is taken mod 1").toBe(0);
  });

  it("plane is isotropic", () => {
    const plane = StringCo.plane(new SeededPrng(13), N);
    const origin = plane.at(0.5, 0.5);
    const alongX = origin.distanceTo(plane.at(0.8, 0.5));
    const alongY = origin.distanceTo(plane.at(0.5, 0.8));
    const diagonal = origin.distanceTo(plane.at(0.5 + 0.3 / Math.sqrt(2), 0.5 + 0.3 / Math.sqrt(2)));
    expectWithin(alongX, alongY, alongY * 0.15);
    expectWithin(diagonal, alongX, alongX * 0.2);
    expect(origin.distanceTo(plane.at(0.55, 0.5))).toBeLessThan(alongX);
  });

  it("every position is a stranger to an unrelated point", () => {
    const prng = new SeededPrng(14);
    const line = StringCo.line(prng, N);
    const stranger = Correlithm.random(prng, N);
    const mu = NCube.standardDistance(N);
    for (const t of [0.0, 0.25, 0.5, 0.75, 1.0]) expectWithin(line.at(t).distanceTo(stranger) / mu, 1, 0.06);
  });

  it("ordinal positions are evenly spaced", () => {
    const line = StringCo.line(new SeededPrng(15), N);
    const a = line.atIndex(0, 26);
    const b = line.atIndex(1, 26);
    const e = line.atIndex(4, 26);
    const z = line.atIndex(25, 26);
    expect(a.distanceTo(b)).toBeLessThan(a.distanceTo(e));
    expect(a.distanceTo(e)).toBeLessThan(a.distanceTo(z));
  });

  it("same seed, same string", () => {
    const a = StringCo.plane(new SeededPrng(16), 64).at(0.2, 0.7);
    const b = StringCo.plane(new SeededPrng(16), 64).at(0.2, 0.7);
    expect(a.equals(b)).toBe(true);
  });

  it("a plane takes two coordinates and a line or ring takes one", () => {
    expect(() => StringCo.plane(new SeededPrng(1), 8).at(0.5)).toThrow(InvalidOperationError);
    expect(() => StringCo.line(new SeededPrng(1), 8).at(0.5, 0.5)).toThrow(InvalidOperationError);
  });
});
