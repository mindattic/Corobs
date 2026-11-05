import { describe, expect, it } from "vitest";
import { ArgumentError, CardinalConverter, ContinuousConverter, Correlithm, NCube, OrdinalConverter, PlanarConverter, SeededPrng } from "../src/index.js";
import { expectWithin } from "./helpers.js";

describe("Converters", () => {
  const N = 128;

  it("cardinal values are fixed tokens at standard distance from each other", () => {
    const c = new CardinalConverter<string>(new SeededPrng(1), N);
    const again = new CardinalConverter<string>(new SeededPrng(1), N);
    const first = c.convert("Underclan");
    expect(c.convert("Underclan"), "a value is one token, cached").toBe(first);
    expect(again.convert("Underclan").equals(first), "same seed, same token, whatever was seen first").toBe(true);
    const mu = NCube.standardDistance(N);
    expectWithin(c.convert("Underclan").distanceTo(c.convert("Arcturus")) / mu, 1, 0.2);
    expect(c.convert(null).equals(Correlithm.midpoint(N))).toBe(true);
  });

  it("ordinal neighbours are closer than extremes and unknowns throw", () => {
    const tiers = ["street", "runner", "fixer", "corpo", "board"];
    const c = new OrdinalConverter(new SeededPrng(2), N, tiers);
    expect(c.convert("street").distanceTo(c.convert("runner"))).toBeLessThan(c.convert("street").distanceTo(c.convert("board")));
    expect(() => c.convert("god")).toThrow(ArgumentError);
    expect(c.convert(null).equals(c.missing)).toBe(true);
    expect(c.count).toBe(5);
  });

  it("continuous values interpolate and can wrap", () => {
    const years = new ContinuousConverter(new SeededPrng(3), N, 2200, 2300);
    expect(years.convert(2230).distanceTo(years.convert(2231))).toBeLessThan(years.convert(2230).distanceTo(years.convert(2290)));
    expect(years.convert(null).equals(years.missing)).toBe(true);
    expect(years.convert(Number.NaN).equals(years.missing)).toBe(true);

    const hours = new ContinuousConverter(new SeededPrng(4), N, 0, 24, true);
    expect(hours.convert(23.5).distanceTo(hours.convert(0.5))).toBeLessThan(hours.convert(23.5).distanceTo(hours.convert(12)));
  });

  it("planar positions are near when the map says so", () => {
    const map = new PlanarConverter(new SeededPrng(5), N, -10, 10, -10, 10);
    const here = map.convert([0.0, 0.0]);
    expect(here.distanceTo(map.convert([0.5, 0.5]))).toBeLessThan(here.distanceTo(map.convert([8.0, -7.0])));
    expect(map.convert(null).equals(map.missing)).toBe(true);
  });

  it("rejects empty orders and empty ranges", () => {
    expect(() => new OrdinalConverter<string>(new SeededPrng(1), N, [])).toThrow(ArgumentError);
    expect(() => new ContinuousConverter(new SeededPrng(1), N, 5, 5)).toThrow(ArgumentError);
    expect(() => new PlanarConverter(new SeededPrng(1), N, 0, 1, 1, 0)).toThrow(ArgumentError);
  });
});
