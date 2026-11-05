import { describe, expect, it } from "vitest";
import { ArgumentOutOfRangeError, Correlithm, NCube, SeededPrng } from "../src/index.js";
import { expectWithin, mean } from "./helpers.js";

describe("NCube: Table II-1 and Ch. III, checked against the cube itself", () => {
  it.each([64, 100])("random points sit at standard distance with the book's deviation (N=%i)", (n) => {
    const prng = new SeededPrng(2004);
    const distances = Array.from({ length: 3000 }, () => Correlithm.random(prng, n).distanceTo(Correlithm.random(prng, n)));
    const m = mean(distances);
    const sd = Math.sqrt(distances.reduce((s, d) => s + (d - m) * (d - m), 0) / (distances.length - 1));
    expectWithin(m, NCube.standardDistance(n), 0.03, "μ = √(N/6)");
    expectWithin(sd, NCube.standardDeviation, 0.025, "σ = √(7/120), independent of N");
  });

  it.each([64, 100])("midpoint and corner distances match the table (N=%i)", (n) => {
    const prng = new SeededPrng(7);
    const mid = Correlithm.midpoint(n);
    const corner = new Correlithm(new Array<number>(n).fill(0));
    const toMid: number[] = [];
    const toCorner: number[] = [];
    for (let i = 0; i < 2000; i++) {
      const p = Correlithm.random(prng, n);
      toMid.push(p.distanceTo(mid));
      toCorner.push(p.distanceTo(corner));
    }
    expectWithin(mean(toMid), NCube.standardRadius(n), 0.02, "standard radius √(N/12)");
    expectWithin(mean(toCorner), NCube.standardDiameter(n), 0.03, "standard diameter √(N/3)");
    expectWithin(NCube.halfDiagonal(n), mid.distanceTo(corner), 1e-12);
  });

  it("bit content follows equation III-H", () => {
    const n = 100;
    const mu = NCube.standardDistance(n);
    expect(NCube.bitContent(n, mu)).toBe(0);
    expect(NCube.bitContent(n, mu + 1), "beyond μ carries nothing").toBe(0);
    // 24.75·(μ−d)² is the book's rounded form of ((μ−d)/σ)²/ln 2.
    expectWithin(NCube.bitContent(n, mu - 1), 24.75, 0.1);
    // Rule of thumb: a little over four bits per dimension at d = 0.
    expectWithin(NCube.bitContent(n, 0) / n, 4.12, 0.02);
    expectWithin(NCube.distanceForBits(n, 24.75), mu - 1, 0.005);
  });

  it("probability of proximity is two to the minus bits", () => {
    const n = 100;
    const mu = NCube.standardDistance(n);
    expect(NCube.probabilityOfProximity(n, mu)).toBe(1);
    // Eq. III-J: 10^(−7.45(μ−d)²); at μ−d = 0.5 → 10^−1.86.
    expectWithin(Math.log10(NCube.probabilityOfProximity(n, mu - 0.5)), -1.86, 0.02);
  });

  it("point capacity follows equation III-Q", () => {
    // Book: N=96, d=1.0 → about 10^33 points before a pair falls within 1.0 of each other.
    expectWithin(Math.log10(NCube.pointCapacity(96, 1.0)), 33.3, 0.3);
    expect(NCube.pointCapacity(96, NCube.standardDistance(96))).toBe(1);
  });

  it("deviations and distances round trip", () => {
    const n = 64;
    const d = NCube.distanceAtDeviations(n, 6);
    expectWithin(NCube.deviationsBelow(n, d), 6, 1e-9);
    expectWithin(NCube.bitContent(n, d), 36 / Math.log(2), 1e-9, "6σ ≈ 52 bits");
  });

  it("rejects a space without dimensions", () => {
    expect(() => NCube.standardDistance(0)).toThrow(ArgumentOutOfRangeError);
    expect(() => NCube.distanceForBits(64, -1)).toThrow(ArgumentOutOfRangeError);
  });
});
