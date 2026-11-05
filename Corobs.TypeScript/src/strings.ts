import { ArgumentOutOfRangeError, InvalidOperationError } from "./errors.js";
import { Correlithm } from "./geometry.js";
import type { SeededPrng } from "./seeding.js";

type Kind = "line" | "ring" | "plane";

const clamp01 = (v: number): number => (v < 0 ? 0 : v > 1 ? 1 : v);

function values(prng: SeededPrng, dimensions: number): [Float64Array, Float64Array] {
  if (!Number.isInteger(dimensions) || dimensions <= 0) throw new ArgumentOutOfRangeError("dimensions");
  const a = new Float64Array(dimensions);
  const b = new Float64Array(dimensions);
  for (let i = 0; i < dimensions; i++) {
    a[i] = prng.nextDouble();
    b[i] = prng.nextDouble();
  }
  return [a, b];
}

/**
 * A string CO (Ch. VII): a lower-dimensional geometry (a line, a ring, a plane) embedded in the N-cube
 * so that distance along the geometry is reflected as distance in the cube, rising from zero to
 * standard distance as positions move apart, while every position stays at standard distance from any
 * unrelated random point.
 *
 * Construction follows the book's advice to "distribute the anomalies randomly": each dimension carries
 * two random values and switches between them at its own random breakpoint along the geometry. No
 * interpolation is involved, so no position "takes a shortcut" toward third points.
 */
export class StringCo {
  readonly #kind: Kind;
  readonly #a: Float64Array;
  readonly #b: Float64Array;
  readonly #o: Float64Array;
  readonly #dx: Float64Array | null;
  readonly #dy: Float64Array | null;

  private constructor(kind: Kind, a: Float64Array, b: Float64Array, o: Float64Array, dx: Float64Array | null, dy: Float64Array | null) {
    this.#kind = kind;
    this.#a = a;
    this.#b = b;
    this.#o = o;
    this.#dx = dx;
    this.#dy = dy;
  }

  /** N: the dimensionality of the cube this geometry is embedded in. */
  get dimensions(): number {
    return this.#a.length;
  }

  /** A line segment parameterised by t ∈ [0, 1]. Distance between t and t′ ≈ μ·√|t − t′|. */
  static line(prng: SeededPrng, dimensions: number): StringCo {
    const [a, b] = values(prng, dimensions);
    const o = new Float64Array(dimensions);
    for (let i = 0; i < dimensions; i++) o[i] = prng.nextDouble();
    return new StringCo("line", a, b, o, null, null);
  }

  /** A closed ring parameterised by t ∈ [0, 1) with 0 ≡ 1, for hours, headings, seasons. Distance
   * between t and t′ ≈ μ·√(2Δ) where Δ is the circular gap (≤ ½). */
  static ring(prng: SeededPrng, dimensions: number): StringCo {
    const [a, b] = values(prng, dimensions);
    const o = new Float64Array(dimensions);
    for (let i = 0; i < dimensions; i++) o[i] = prng.nextDouble();
    return new StringCo("ring", a, b, o, null, null);
  }

  /** A unit square parameterised by (x, y) ∈ [0, 1]². Each dimension watches a random direction, so
   * distance grows with planar separation in every direction alike: the symmetric "cone" of
   * Fig. VII-10, without the troughs of concatenated 1-D strings (Fig. VII-11). */
  static plane(prng: SeededPrng, dimensions: number): StringCo {
    const [a, b] = values(prng, dimensions);
    const o = new Float64Array(dimensions);
    const dx = new Float64Array(dimensions);
    const dy = new Float64Array(dimensions);
    for (let i = 0; i < dimensions; i++) {
      const theta = prng.nextDouble() * 2 * Math.PI;
      dx[i] = Math.cos(theta);
      dy[i] = Math.sin(theta);
      const min = Math.min(0, dx[i]!) + Math.min(0, dy[i]!);
      const max = Math.max(0, dx[i]!) + Math.max(0, dy[i]!);
      o[i] = min + prng.nextDouble() * (max - min);
    }
    return new StringCo("plane", a, b, o, dx, dy);
  }

  /** The point at position t on a line (clamped to [0, 1]) or a ring (taken mod 1); or, given two
   * coordinates, the point at (x, y) on a plane, each clamped to [0, 1]. */
  at(t: number): Correlithm;
  at(x: number, y: number): Correlithm;
  at(x: number, y?: number): Correlithm {
    return y === undefined ? this.#at1(x) : this.#at2(x, y);
  }

  #at1(t: number): Correlithm {
    if (this.#kind === "plane") throw new InvalidOperationError("A planar string CO takes two coordinates.");
    if (Number.isNaN(t)) throw new ArgumentOutOfRangeError("t");
    const n = this.dimensions;
    const c = new Array<number>(n);
    if (this.#kind === "line") {
      t = clamp01(t);
      for (let i = 0; i < n; i++) c[i] = t < this.#o[i]! ? this.#a[i]! : this.#b[i]!;
    } else {
      // COR-T4 (docs/BUGS.md): infinity has no phase on a ring.
      if (!Number.isFinite(t)) throw new ArgumentOutOfRangeError("t");
      for (let i = 0; i < n; i++) {
        let phase = t - this.#o[i]!;
        phase -= Math.floor(phase);
        c[i] = phase < 0.5 ? this.#a[i]! : this.#b[i]!;
      }
    }
    return new Correlithm(c);
  }

  #at2(x: number, y: number): Correlithm {
    if (this.#kind !== "plane") throw new InvalidOperationError("Only a planar string CO takes two coordinates.");
    if (Number.isNaN(x) || Number.isNaN(y)) throw new ArgumentOutOfRangeError("x");
    x = clamp01(x);
    y = clamp01(y);
    const n = this.dimensions;
    const c = new Array<number>(n);
    const dx = this.#dx!;
    const dy = this.#dy!;
    for (let i = 0; i < n; i++) {
      const p = x * dx[i]! + y * dy[i]!;
      c[i] = p < this.#o[i]! ? this.#a[i]! : this.#b[i]!;
    }
    return new Correlithm(c);
  }

  /** The index-th of count evenly spaced positions: an ordinal set such as an alphabet, a rank or a
   * tier (Fig. VII-8). */
  atIndex(index: number, count: number): Correlithm {
    if (!Number.isInteger(count) || count <= 0) throw new ArgumentOutOfRangeError("count");
    if (!Number.isInteger(index) || index < 0 || index >= count) throw new ArgumentOutOfRangeError("index");
    if (this.#kind === "ring") return this.at(index / count);
    return this.at(count === 1 ? 0 : index / (count - 1));
  }
}
