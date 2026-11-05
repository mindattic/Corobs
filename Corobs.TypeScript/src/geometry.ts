import { ArgumentError, ArgumentOutOfRangeError } from "./errors.js";
import type { SeededPrng } from "./seeding.js";

function check(dimensions: number): number {
  if (!Number.isInteger(dimensions) || dimensions <= 0)
    throw new ArgumentOutOfRangeError("dimensions", "A space needs at least one dimension; the statistics hold from about 20.");
  return dimensions;
}

/**
 * The statistics of the real unit N-cube (Lawrence, Correlithm Object Technology, Ch. II–III). Two
 * points chosen at random are almost always standard distance apart, with a standard deviation that
 * does not grow with N (Table II-1). Proximity far below that distance is information: bitContent says
 * how much (Eq. III-H), probabilityOfProximity how unlikely by chance (Eq. III-J), pointCapacity how
 * many random points fit before two collide (Eq. III-Q). Valid for N of about 20 and up.
 */
export const NCube = {
  /** σ of the distance between two random points: √(7/120) ≈ 0.2415, independent of N. */
  standardDeviation: 0.24152294576982397,
  /** σ of the distance from the midpoint to a random point: √(1/60) ≈ 0.1291. */
  radiusDeviation: 0.12909944487358055,
  /** σ of the distance from a corner to a random point: √(1/15) ≈ 0.2582. */
  diameterDeviation: 0.2581988897471611,

  /** μ: expected distance between two random points, √(N/6). */
  standardDistance: (dimensions: number): number => Math.sqrt(check(dimensions) / 6.0),
  /** Expected distance from the midpoint to a random point, √(N/12). */
  standardRadius: (dimensions: number): number => Math.sqrt(check(dimensions) / 12.0),
  /** Expected distance from a corner to a random point, √(N/3). */
  standardDiameter: (dimensions: number): number => Math.sqrt(check(dimensions) / 3.0),
  /** Expected distance between two random corners, √(N/2). */
  cornerDistance: (dimensions: number): number => Math.sqrt(check(dimensions) / 2.0),
  /** Midpoint to any corner, exactly √(N/4). */
  halfDiagonal: (dimensions: number): number => Math.sqrt(check(dimensions) / 4.0),
  /** Opposite corners, exactly √N. */
  majorDiagonal: (dimensions: number): number => Math.sqrt(check(dimensions)),

  /** How many standard deviations below μ a distance lies (negative when beyond μ). */
  deviationsBelow(dimensions: number, distance: number): number {
    return (NCube.standardDistance(dimensions) - distance) / NCube.standardDeviation;
  },

  /** The distance that lies `deviations` σ below μ. */
  distanceAtDeviations(dimensions: number, deviations: number): number {
    return NCube.standardDistance(dimensions) - deviations * NCube.standardDeviation;
  },

  /** Eq. III-H: bits of information in two points lying `distance` apart, ((μ − d)/σ)² / ln 2.
   * Zero at or beyond standard distance. */
  bitContent(dimensions: number, distance: number): number {
    const x = NCube.deviationsBelow(dimensions, distance);
    return x <= 0 ? 0 : (x * x) / Math.log(2);
  },

  /** The distance at which proximity is worth `bits` bits. */
  distanceForBits(dimensions: number, bits: number): number {
    if (bits < 0) throw new ArgumentOutOfRangeError("bits");
    return NCube.standardDistance(dimensions) - NCube.standardDeviation * Math.sqrt(bits * Math.log(2));
  },

  /** Eq. III-J: the probability that two random points lie closer than `distance`, 2^(−bits). */
  probabilityOfProximity(dimensions: number, distance: number): number {
    return Math.pow(2, -NCube.bitContent(dimensions, distance));
  },

  /** Eq. III-Q: how many random points can be placed before two are expected to lie closer than
   * `distance`, 10^(3.7(μ − d)²). */
  pointCapacity(dimensions: number, distance: number): number {
    const gap = NCube.standardDistance(dimensions) - distance;
    return gap <= 0 ? 1 : Math.pow(10, 3.7 * gap * gap);
  },
} as const;

/**
 * A correlithm object: one point in the real unit N-cube, every coordinate in [0, 1]. A CO is a soft
 * token (Ch. IV): it stands for its datum exactly at its coordinates and, to a degree
 * NCube.bitContent quantifies, at every point nearby. Immutable.
 */
export class Correlithm {
  readonly #c: Float64Array;

  /** A point at exactly these coordinates; each must lie in [0, 1]. */
  constructor(coordinates: ArrayLike<number>) {
    if (coordinates.length === 0) throw new ArgumentError("A point needs at least one coordinate.", "coordinates");
    for (let i = 0; i < coordinates.length; i++) {
      const v = coordinates[i]!;
      if (Number.isNaN(v) || v < 0 || v > 1) throw new ArgumentOutOfRangeError("coordinates", "Every coordinate must lie in [0, 1].");
    }
    this.#c = Float64Array.from(coordinates);
  }

  /** N: the dimensionality of the cube this point lives in. */
  get dimensions(): number {
    return this.#c.length;
  }

  /** The coordinate on one dimension, in [0, 1]. */
  at(dimension: number): number {
    if (!Number.isInteger(dimension) || dimension < 0 || dimension >= this.#c.length) throw new ArgumentOutOfRangeError("dimension");
    return this.#c[dimension]!;
  }

  /** All N coordinates, in order (a copy). */
  get coordinates(): number[] {
    return Array.from(this.#c);
  }

  /** A point chosen uniformly at random from the whole cube: a fresh token, at standard distance from
   * every other random token with overwhelming probability. */
  static random(prng: SeededPrng, dimensions: number): Correlithm {
    const c = new Array<number>(check(dimensions));
    for (let i = 0; i < c.length; i++) c[i] = prng.nextDouble();
    return new Correlithm(c);
  }

  /** The cube's centre, 0.5 in every dimension: where a missing value goes, because the midpoint is
   * at standard radius from everything and carries no bits. */
  static midpoint(dimensions: number): Correlithm {
    return new Correlithm(new Array<number>(check(dimensions)).fill(0.5));
  }

  /** Euclidean distance squared to `other`, from the same cube. */
  squaredDistanceTo(other: Correlithm): number {
    this.#checkSame(other);
    const a = this.#c;
    const b = other.#c;
    let s = 0;
    for (let i = 0; i < a.length; i++) {
      const d = a[i]! - b[i]!;
      s += d * d;
    }
    return s;
  }

  /** Euclidean distance to `other`; compare against NCube.standardDistance to read it as information. */
  distanceTo(other: Correlithm): number {
    return Math.sqrt(this.squaredDistanceTo(other));
  }

  /** Linear interpolation by `fraction` from this point toward `other`. Ch. VII warns that
   * interpolated points "take a shortcut"; use StringCo for sequences. */
  interpolate(other: Correlithm, fraction: number): Correlithm {
    this.#checkSame(other);
    if (fraction < 0 || fraction > 1) throw new ArgumentOutOfRangeError("fraction");
    const c = new Array<number>(this.#c.length);
    for (let i = 0; i < c.length; i++) c[i] = this.#c[i]! + (other.#c[i]! - this.#c[i]!) * fraction;
    return new Correlithm(c);
  }

  /** The coordinate-wise mean of a set of points. */
  static centroid(points: Iterable<Correlithm>): Correlithm {
    let sum: Float64Array | null = null;
    let count = 0;
    for (const p of points) {
      sum ??= new Float64Array(p.dimensions);
      if (sum.length !== p.dimensions) throw new ArgumentError("All points must share one dimensionality.", "points");
      for (let i = 0; i < sum.length; i++) sum[i] = sum[i]! + p.#c[i]!;
      count++;
    }
    if (sum === null) throw new ArgumentError("A centroid needs at least one point.", "points");
    for (let i = 0; i < sum.length; i++) sum[i] = sum[i]! / count;
    return new Correlithm(sum);
  }

  /** A point that superposes several: their centroid (Ch. VIII, Superposition). */
  static superpose(points: Iterable<Correlithm>): Correlithm {
    return Correlithm.centroid(points);
  }

  /** True when every coordinate matches exactly; not a proximity test. */
  equals(other: Correlithm | null | undefined): boolean {
    if (!other || other.#c.length !== this.#c.length) return false;
    for (let i = 0; i < this.#c.length; i++) if (!Object.is(this.#c[i], other.#c[i]) && this.#c[i] !== other.#c[i]) return false;
    return true;
  }

  /** Just the dimensionality; coordinates are not meant to be read as text. */
  toString(): string {
    return `CO[${this.dimensions}]`;
  }

  #checkSame(other: Correlithm): void {
    if (other.#c.length !== this.#c.length) throw new ArgumentError("Points from different spaces have no distance.", "other");
  }
}
