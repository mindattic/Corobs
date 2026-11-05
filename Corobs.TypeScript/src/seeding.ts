import { ArgumentOutOfRangeError } from "./errors.js";

const MASK64 = (1n << 64n) - 1n;
const INT64_MIN = -(1n << 63n);
const INT64_MAX = (1n << 63n) - 1n;
const FNV_OFFSET = 14695981039346656037n;
const FNV_PRIME = 1099511628211n;

/** A signed 64-bit seed: a bigint in the int64 range, or a safe integer number. */
export type Seed = bigint | number;

function toInt64(seed: Seed): bigint {
  if (typeof seed === "number") {
    if (!Number.isSafeInteger(seed)) throw new ArgumentOutOfRangeError("seed", "A number seed must be a safe integer; pass a bigint for the full 64-bit range.");
    return BigInt(seed);
  }
  if (seed < INT64_MIN || seed > INT64_MAX) throw new ArgumentOutOfRangeError("seed", "A seed must lie in the signed 64-bit range.");
  return seed;
}

const rotl = (x: bigint, k: bigint): bigint => ((x << k) | (x >> (64n - k))) & MASK64;

/** UTF-8 bytes of a JS string; a lone surrogate becomes U+FFFD, as .NET's Encoding.UTF8 does. */
export function utf8(text: string): number[] {
  const out: number[] = [];
  for (let i = 0; i < text.length; i++) {
    let cp = text.charCodeAt(i);
    if (cp >= 0xd800 && cp <= 0xdbff && i + 1 < text.length) {
      const lo = text.charCodeAt(i + 1);
      if (lo >= 0xdc00 && lo <= 0xdfff) {
        cp = 0x10000 + ((cp - 0xd800) << 10) + (lo - 0xdc00);
        i++;
      } else cp = 0xfffd;
    } else if (cp >= 0xd800 && cp <= 0xdfff) cp = 0xfffd;
    if (cp < 0x80) out.push(cp);
    else if (cp < 0x800) out.push(0xc0 | (cp >> 6), 0x80 | (cp & 0x3f));
    else if (cp < 0x10000) out.push(0xe0 | (cp >> 12), 0x80 | ((cp >> 6) & 0x3f), 0x80 | (cp & 0x3f));
    else out.push(0xf0 | (cp >> 18), 0x80 | ((cp >> 12) & 0x3f), 0x80 | ((cp >> 6) & 0x3f), 0x80 | (cp & 0x3f));
  }
  return out;
}

/**
 * A deterministic pseudo-random stream (xoshiro256** seeded through SplitMix64). The same seed yields
 * the same doubles on every machine and in every language port. Everything stochastic in COROBS
 * draws from one of these, so a space can be rebuilt bit-for-bit from its seed.
 */
export class SeededPrng {
  /** The root seed this stream (or derive chain) was built from, as a signed 64-bit bigint. */
  readonly seed: bigint;
  #s0: bigint;
  #s1: bigint;
  #s2: bigint;
  #s3: bigint;

  /** A fresh stream; the same seed always produces the same sequence. */
  constructor(seed: Seed) {
    this.seed = toInt64(seed);
    let x = BigInt.asUintN(64, this.seed);
    const next = (): bigint => {
      x = (x + 0x9e3779b97f4a7c15n) & MASK64;
      let z = x;
      z = ((z ^ (z >> 30n)) * 0xbf58476d1ce4e5b9n) & MASK64;
      z = ((z ^ (z >> 27n)) * 0x94d049bb133111ebn) & MASK64;
      return z ^ (z >> 31n);
    };
    this.#s0 = next();
    this.#s1 = next();
    this.#s2 = next();
    this.#s3 = next();
  }

  /** A child stream named by `label`: the same parent seed and label always give the same child,
   * independent of how many values the parent has produced (FNV-1a over the seed's 8 little-endian
   * bytes, then the label's UTF-8 bytes). */
  derive(label: string): SeededPrng {
    let h = FNV_OFFSET;
    const s = BigInt.asUintN(64, this.seed);
    for (let i = 0n; i < 8n; i++) {
      h ^= (s >> (8n * i)) & 0xffn;
      h = (h * FNV_PRIME) & MASK64;
    }
    for (const b of utf8(label)) {
      h ^= BigInt(b);
      h = (h * FNV_PRIME) & MASK64;
    }
    return new SeededPrng(BigInt.asIntN(64, h));
  }

  /** The next raw 64-bit word of the xoshiro256** stream, as an unsigned bigint. */
  nextUInt64(): bigint {
    const result = (rotl((this.#s1 * 5n) & MASK64, 7n) * 9n) & MASK64;
    const t = (this.#s1 << 17n) & MASK64;
    this.#s2 ^= this.#s0;
    this.#s3 ^= this.#s1;
    this.#s1 ^= this.#s2;
    this.#s0 ^= this.#s3;
    this.#s2 ^= t;
    this.#s3 = rotl(this.#s3, 45n);
    return result;
  }

  /** Uniform on [0, 1). */
  nextDouble(): number {
    return Number(this.nextUInt64() >> 11n) * 2 ** -53;
  }

  /** Uniform integer on [0, maxExclusive); maxExclusive is a positive 32-bit integer. */
  next(maxExclusive: number): number {
    if (!Number.isInteger(maxExclusive) || maxExclusive <= 0 || maxExclusive > 0x7fffffff) throw new ArgumentOutOfRangeError("maxExclusive");
    return Math.trunc(this.nextDouble() * maxExclusive);
  }
}
