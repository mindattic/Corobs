import { ArgumentError } from "./errors.js";
import { Correlithm } from "./geometry.js";
import type { SeededPrng } from "./seeding.js";
import { StringCo } from "./strings.js";

/** Moves world data into CO space (a sensor, Ch. IX). Every converter answers the same question for a
 * missing value: the cube's midpoint, which carries no bits. */
export interface Converter<T> {
  /** N: the dimensionality of the points this converter produces. */
  readonly dimensions: number;
  /** Where an absent value lands: Correlithm.midpoint. */
  readonly missing: Correlithm;
  /** The point for a value, or `missing` for null/undefined. */
  convert(value: T | null | undefined): Correlithm;
}

/** A cardinal set: values with no order (a faction, a species, a type). Each distinct value gets its
 * own random CO, derived from the seed and the value's key, so the mapping is the same on every build
 * regardless of the order values were first seen. The key defaults to String(value); pass one when
 * values are not strings or integers, so every language port derives the same text. */
export class CardinalConverter<T> implements Converter<T> {
  readonly dimensions: number;
  readonly missing: Correlithm;
  readonly #root: SeededPrng;
  readonly #key: (value: T) => string;
  readonly #cache = new Map<string, Correlithm>();

  constructor(root: SeededPrng, dimensions: number, key?: (value: T) => string) {
    this.#root = root;
    this.#key = key ?? ((v) => String(v));
    this.dimensions = dimensions;
    this.missing = Correlithm.midpoint(dimensions);
  }

  /** The value's CO (created and cached on first use), or `missing` for null/undefined. */
  convert(value: T | null | undefined): Correlithm {
    if (value === null || value === undefined) return this.missing;
    const k = this.#key(value);
    let co = this.#cache.get(k);
    if (co === undefined) {
      co = Correlithm.random(this.#root.derive(k), this.dimensions);
      this.#cache.set(k, co);
    }
    return co;
  }
}

/** An ordinal set: values with an order but no scale (tiers, ranks, an alphabet), evenly spaced on a
 * line string CO so neighbours are near and the extremes are at standard distance (Fig. VII-8). An
 * unknown value is an error, not a guess. `key` maps a value to its identity (default: the value). */
export class OrdinalConverter<T> implements Converter<T> {
  readonly dimensions: number;
  readonly missing: Correlithm;
  readonly #index = new Map<unknown, number>();
  readonly #key: (value: T) => unknown;
  readonly #line: StringCo;

  constructor(prng: SeededPrng, dimensions: number, order: readonly T[], key?: (value: T) => unknown) {
    if (order.length === 0) throw new ArgumentError("An ordinal set needs at least one value.", "order");
    this.#key = key ?? ((v) => v);
    for (let i = 0; i < order.length; i++) {
      const k = this.#key(order[i]!);
      if (this.#index.has(k)) throw new ArgumentError("An item with the same key has already been added.", "order");
      this.#index.set(k, i);
    }
    this.#line = StringCo.line(prng, dimensions);
    this.dimensions = dimensions;
    this.missing = Correlithm.midpoint(dimensions);
  }

  /** How many distinct values are in the order. */
  get count(): number {
    return this.#index.size;
  }

  /** The value's position on the line (`missing` for null/undefined); throws for a value outside the
   * ordered set, since there is no sensible place to guess it belongs. */
  convert(value: T | null | undefined): Correlithm {
    if (value === null || value === undefined) return this.missing;
    const i = this.#index.get(this.#key(value));
    if (i === undefined) throw new ArgumentError(`'${String(value)}' is not in this ordinal set.`, "value");
    return this.#line.atIndex(i, this.#index.size);
  }
}

/** A continuous variable on [min, max] (an age, a date, a price) mapped onto a line string CO, or onto
 * a ring when the range wraps (hours of the day, compass bearings). */
export class ContinuousConverter implements Converter<number> {
  readonly dimensions: number;
  readonly missing: Correlithm;
  readonly #string: StringCo;
  readonly #min: number;
  readonly #max: number;
  readonly #wraps: boolean;

  constructor(prng: SeededPrng, dimensions: number, min: number, max: number, wraps = false) {
    if (!(max > min)) throw new ArgumentError("max must exceed min.", "max");
    this.#string = wraps ? StringCo.ring(prng, dimensions) : StringCo.line(prng, dimensions);
    this.#min = min;
    this.#max = max;
    this.#wraps = wraps;
    this.dimensions = dimensions;
    this.missing = Correlithm.midpoint(dimensions);
  }

  /** The value's point on the string (`missing` for null/undefined, NaN, or an infinite value on a
   * ring, which has no phase to land on). */
  convert(value: number | null | undefined): Correlithm {
    if (value === null || value === undefined || Number.isNaN(value)) return this.missing;
    // COR-T5 (docs/BUGS.md, a decision): a ring has no phase for infinity.
    if (this.#wraps && !Number.isFinite(value)) return this.missing;
    const t = (value - this.#min) / (this.#max - this.#min);
    return this.#string.at(t);
  }
}

/** A position in a bounded plane, as [x, y]. */
export type PlanarValue = readonly [x: number, y: number];

/** A point in a bounded plane (a map position) on a planar string CO (Fig. VII-10). */
export class PlanarConverter implements Converter<PlanarValue> {
  readonly dimensions: number;
  readonly missing: Correlithm;
  readonly #plane: StringCo;
  readonly #minX: number;
  readonly #maxX: number;
  readonly #minY: number;
  readonly #maxY: number;

  constructor(prng: SeededPrng, dimensions: number, minX: number, maxX: number, minY: number, maxY: number) {
    if (!(maxX > minX) || !(maxY > minY)) throw new ArgumentError("Each axis needs max > min.");
    this.#plane = StringCo.plane(prng, dimensions);
    this.#minX = minX;
    this.#maxX = maxX;
    this.#minY = minY;
    this.#maxY = maxY;
    this.dimensions = dimensions;
    this.missing = Correlithm.midpoint(dimensions);
  }

  /** The value's point on the plane (`missing` for null/undefined or a NaN coordinate). */
  convert(value: PlanarValue | null | undefined): Correlithm {
    if (value === null || value === undefined) return this.missing;
    const [x, y] = value;
    if (Number.isNaN(x) || Number.isNaN(y)) return this.missing;
    return this.#plane.at((x - this.#minX) / (this.#maxX - this.#minX), (y - this.#minY) / (this.#maxY - this.#minY));
  }
}
