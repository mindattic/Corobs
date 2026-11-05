import { ArgumentOutOfRangeError } from "./errors.js";
import type { KeyOf } from "./mining.js";
import { SeededPrng, type Seed } from "./seeding.js";

/** How well a neighbour function recovers relationships that were hidden from it. */
export class RecallResult {
  constructor(
    readonly hidden: number,
    readonly recovered: number,
    readonly predicted: number,
    readonly predictedTrue: number,
  ) {}

  /** Share of the hidden pairs that the predictor recovered. */
  get recall(): number {
    return this.hidden === 0 ? 0 : this.recovered / this.hidden;
  }

  /** Share of the predictor's own guesses that were actually true (anywhere in the full truth). */
  get precision(): number {
    return this.predicted === 0 ? 0 : this.predictedTrue / this.predicted;
  }
}

/** How far a thing can reach through a relationship: mean reachable count per hop and how many things
 * reach nothing at all (dead records). */
export interface ReachResult {
  readonly meanReachableByHop: readonly number[];
  readonly isolated: number;
  readonly total: number;
}

/** A pair of ids. */
export type IdPair<TId> = readonly [TId, TId];

/** Round half to even, as C#'s Math.Round does by default. */
export function roundHalfEven(x: number): number {
  const r = Math.round(x);
  return Math.abs(x % 1) === 0.5 && r % 2 !== 0 ? r - 1 : r;
}

const identity = <TId>(id: TId): unknown => id;

function encode(k: unknown): string {
  const s = typeof k === "string" ? k : String(k);
  return `${typeof k}:${s.length}:${s}`;
}

/**
 * Scores any way of relating things against any other on the same ground truth: the old way and the
 * COROBS way answer the same questions, and these are the questions. Everything here is arithmetic over
 * ids; the caller supplies the truth and the predictors.
 */
export const Bench = {
  /**
   * Hide `holdoutFraction` of the true relationships (deterministically, by seed), ask the predictor for
   * each hidden endpoint's neighbours, and count how many hidden pairs come back. A relationship is an
   * unordered pair under `key` (default: the id itself). Precision counts predicted neighbours of those
   * endpoints that are true pairs anywhere in the full truth.
   */
  holdoutRecall<TId>(truePairs: readonly IdPair<TId>[], holdoutFraction: number, seed: Seed, neighbours: (id: TId) => Iterable<TId>, key: KeyOf<TId> = identity): RecallResult {
    if (holdoutFraction <= 0 || holdoutFraction >= 1) throw new ArgumentOutOfRangeError("holdoutFraction");
    const canon = (p: IdPair<TId>): IdPair<TId> => (String(p[0]) <= String(p[1]) ? [p[0], p[1]] : [p[1], p[0]]);
    const pairKey = (p: IdPair<TId>): string => {
      const a = encode(key(p[0]));
      const b = encode(key(p[1]));
      return a <= b ? `${a.length}|${a}${b}` : `${b.length}|${b}${a}`;
    };
    const truth = new Set(truePairs.map(pairKey));

    const prng = new SeededPrng(seed);
    // COR-T4 (docs/BUGS.md): a pair listed twice, or both ways round, is one relationship to hide.
    const distinct = new Set<string>();
    const shuffled: IdPair<TId>[] = [];
    for (const p of truePairs) {
      const k = pairKey(p);
      if (distinct.has(k)) continue;
      distinct.add(k);
      shuffled.push(canon(p));
    }
    for (let i = shuffled.length - 1; i > 0; i--) {
      const j = prng.next(i + 1);
      [shuffled[i], shuffled[j]] = [shuffled[j]!, shuffled[i]!];
    }
    const hidden = shuffled.slice(0, roundHalfEven(shuffled.length * holdoutFraction)).map(canon);
    const hiddenSet = new Set(hidden.map(pairKey));

    let recovered = 0;
    let predicted = 0;
    let predictedTrue = 0;
    const endpoints = new Map<unknown, TId>();
    for (const [a, b] of hidden) {
      if (!endpoints.has(key(a))) endpoints.set(key(a), a);
      if (!endpoints.has(key(b))) endpoints.set(key(b), b);
    }
    const seen = new Set<string>();
    for (const e of endpoints.values())
      for (const nb of neighbours(e)) {
        const k = pairKey(canon([e, nb]));
        if (seen.has(k)) continue;
        seen.add(k);
        predicted++;
        if (truth.has(k)) predictedTrue++;
        if (hiddenSet.delete(k)) recovered++;
      }
    return new RecallResult(hidden.length, recovered, predicted, predictedTrue);
  },

  /** Breadth-first reach from every id through `adjacency`, up to `maxHops`. */
  reach<TId>(ids: Iterable<TId>, adjacency: (id: TId) => Iterable<TId>, maxHops: number, key: KeyOf<TId> = identity): ReachResult {
    if (!Number.isInteger(maxHops) || maxHops <= 0) throw new ArgumentOutOfRangeError("maxHops");
    const all = Array.from(ids);
    const sums = new Array<number>(maxHops).fill(0);
    let isolated = 0;
    for (const start of all) {
      const visited = new Set<unknown>([key(start)]);
      let frontier: TId[] = [start];
      let reached = 0;
      for (let hop = 0; hop < maxHops; hop++) {
        const next: TId[] = [];
        for (const f of frontier)
          for (const a of adjacency(f)) {
            const k = key(a);
            if (!visited.has(k)) {
              visited.add(k);
              next.push(a);
            }
          }
        reached += next.length;
        sums[hop] = sums[hop]! + reached;
        frontier = next;
        if (next.length === 0) {
          for (let h = hop + 1; h < maxHops; h++) sums[h] = sums[h]! + reached;
          break;
        }
      }
      if (reached === 0) isolated++;
    }
    return { meanReachableByHop: sums.map((s) => (all.length === 0 ? 0 : s / all.length)), isolated, total: all.length };
  },

  /** Hits that closed because something else was fixed, per direct fix. The old way scores zero by
   * construction; that is a fact to report, not to hide. */
  cascadeYield(closedByCascade: number, directFixes: number): number {
    return directFixes === 0 ? 0 : closedByCascade / directFixes;
  },
} as const;
