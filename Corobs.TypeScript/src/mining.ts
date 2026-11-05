import { ArgumentError, ArgumentOutOfRangeError } from "./errors.js";
import { Correlithm, NCube } from "./geometry.js";

/** Orders two ids: negative, zero or positive. */
export type Compare<TId> = (a: TId, b: TId) => number;

/** Maps an id to its identity for equality (a primitive: string, number, bigint, boolean). */
export type KeyOf<TId> = (id: TId) => unknown;

/** The default id order: numbers and bigints numerically, strings by UTF-16 code units (C# ordinal). */
export const defaultCompare = <TId>(a: TId, b: TId): number => (a < b ? -1 : a > b ? 1 : 0);

const identity = <TId>(id: TId): unknown => id;

/** One thing's position on one ply (subspace). */
export interface PlyPoint<TId> {
  readonly id: TId;
  readonly point: Correlithm;
}

/**
 * An emergent truth: a set of things whose points on one ply lie far closer together than chance
 * allows. Proposed by PatternMiner; what it means, and whether it is true, is the caller's hand decision.
 */
export class Pattern<TId> {
  readonly #set: Set<unknown>;
  readonly #key: KeyOf<TId>;

  /** A pattern over the given members and their already-computed geometry; callers normally get one
   * from PatternMiner rather than constructing it directly. */
  constructor(
    /** The ids of the things in this cluster. */
    readonly members: readonly TId[],
    /** The mean point of the members: what a rule's source or target pattern pulls toward. */
    readonly centroid: Correlithm,
    /** The furthest any member lies from the centroid. */
    readonly radius: number,
    /** The mean distance between members, pairwise. */
    readonly meanPairDistance: number,
    /** Eq. III-H bits of the mean pair distance: how far below chance this cluster is. */
    readonly bits: number,
    key?: KeyOf<TId>,
  ) {
    this.#key = key ?? identity;
    this.#set = new Set(members.map((m) => this.#key(m)));
  }

  /** Whether `id` is one of this pattern's members. */
  contains(id: TId): boolean {
    return this.#set.has(this.#key(id));
  }

  /** The member count and bits, for logs and reports. */
  toString(): string {
    return `Pattern[${this.members.length} members, ${this.bits.toFixed(1)} bits]`;
  }
}

function find(parent: number[], i: number): number {
  while (parent[i] !== i) {
    parent[i] = parent[parent[i]!]!;
    i = parent[i]!;
  }
  return i;
}

function union(parent: number[], a: number, b: number): void {
  const ra = find(parent, a);
  const rb = find(parent, b);
  if (ra === rb) return;
  if (ra < rb) parent[rb] = ra;
  else parent[ra] = rb;
}

/**
 * Finds the clusters on one ply that are far tighter than chance: two points are linked when they lie
 * at least `minDeviations` σ below standard distance (≈ 52 bits at 6σ, Eq. III-H), linked points are
 * joined by union-find, and a component with at least `minMembers` members is a proposed Pattern.
 * Deterministic: points are processed in id order, and the output is ordered by bits then by first member.
 */
export class PatternMiner {
  /** A miner that links points at `minDeviations` σ below standard distance (default 6, ≈ 52 bits) and
   * keeps clusters of at least `minMembers` (default 5). */
  constructor(
    readonly minDeviations = 6,
    readonly minMembers = 5,
  ) {
    if (minDeviations <= 0) throw new ArgumentOutOfRangeError("minDeviations");
    if (!Number.isInteger(minMembers) || minMembers < 2) throw new ArgumentOutOfRangeError("minMembers");
  }

  /** The patterns found among `points` (all on the same ply), ordered by bits descending then by first
   * member under `order`; `key` is passed through to each Pattern for membership tests. */
  mine<TId>(points: readonly PlyPoint<TId>[], order: Compare<TId> = defaultCompare, key?: KeyOf<TId>): Pattern<TId>[] {
    if (points.length < this.minMembers) return [];
    const n = points[0]!.point.dimensions;
    const sorted = [...points].sort((p, q) => order(p.id, q.id));
    const threshold = NCube.distanceAtDeviations(n, this.minDeviations);
    // COR-T4 (docs/BUGS.md): distance is never negative, so a negative threshold links nothing.
    if (threshold < 0) return [];
    const thresholdSq = threshold * threshold;

    const parent = sorted.map((_, i) => i);
    for (let i = 0; i < sorted.length; i++) {
      const pi = sorted[i]!.point;
      for (let j = i + 1; j < sorted.length; j++) if (pi.squaredDistanceTo(sorted[j]!.point) <= thresholdSq) union(parent, i, j);
    }

    const groups = new Map<number, number[]>();
    for (let i = 0; i < sorted.length; i++) {
      const root = find(parent, i);
      let list = groups.get(root);
      if (list === undefined) groups.set(root, (list = []));
      list.push(i);
    }

    const result: Pattern<TId>[] = [];
    for (const members of groups.values()) {
      if (members.length < this.minMembers) continue;
      const pts = members.map((i) => sorted[i]!.point);
      const centroid = Correlithm.centroid(pts);
      let radius = -Infinity;
      for (const p of pts) radius = Math.max(radius, p.distanceTo(centroid));
      let sum = 0;
      let pairs = 0;
      for (let a = 0; a < pts.length; a++)
        for (let b = a + 1; b < pts.length; b++) {
          sum += pts[a]!.distanceTo(pts[b]!);
          pairs++;
        }
      const mean = sum / pairs;
      result.push(new Pattern(members.map((i) => sorted[i]!.id), centroid, radius, mean, NCube.bitContent(n, mean), key));
    }

    return result.sort((p, q) => (p.bits > q.bits ? -1 : p.bits < q.bits ? 1 : order(p.members[0]!, q.members[0]!)));
  }
}

/**
 * A rule s.p >: t.q (Ch. IV): things inside pattern `source` on ply `sourcePly` are found inside
 * pattern `target` on ply `targetPly` with the given support. These are the strings that pull.
 */
export class Rule<TId> {
  constructor(
    readonly sourcePly: string,
    readonly source: Pattern<TId>,
    readonly targetPly: string,
    readonly target: Pattern<TId>,
    readonly support: number,
    readonly bits: number,
  ) {}

  /** The rule's plies, pattern sizes, support and bits, for logs and reports. */
  toString(): string {
    return `${this.sourcePly}.[${this.source.members.length}] >: ${this.targetPly}.[${this.target.members.length}] support ${Math.round(this.support * 100)}%, ${this.bits.toFixed(1)} bits`;
  }
}

/**
 * Proposes rules between the patterns of two plies: for every source pattern, the target pattern that
 * holds the largest share of its members, kept when that share reaches `minSupport`.
 * Bits = support × the source pattern's bits. Deterministic.
 */
export class RuleMiner {
  /** A miner that proposes rules whose support reaches `minSupport` (default 0.8). */
  constructor(readonly minSupport = 0.8) {
    if (minSupport <= 0 || minSupport > 1) throw new ArgumentOutOfRangeError("minSupport");
  }

  /** The rules from `sourcePly`'s patterns to `targetPly`'s that reach minSupport, ordered by bits
   * descending. */
  mine<TId>(sourcePly: string, source: readonly Pattern<TId>[], targetPly: string, target: readonly Pattern<TId>[]): Rule<TId>[] {
    if (sourcePly === targetPly) throw new ArgumentError("A rule relates two different plies.", "targetPly");
    const rules: Rule<TId>[] = [];
    for (const p of source) {
      let best: Pattern<TId> | null = null;
      let bestCount = 0;
      for (const q of target) {
        let count = 0;
        for (const m of p.members) if (q.contains(m)) count++;
        if (count > bestCount) {
          best = q;
          bestCount = count;
        }
      }
      if (best === null) continue;
      const support = bestCount / p.members.length;
      if (support >= this.minSupport) rules.push(new Rule(sourcePly, p, targetPly, best, support, support * p.bits));
    }
    return rules.sort((a, b) => (a.bits > b.bits ? -1 : a.bits < b.bits ? 1 : 0));
  }
}

/**
 * A ranked contradiction candidate: a thing that sits inside a rule's source pattern yet lies at or
 * near standard distance from the rule's target: the anomaly a cueing system hands to the expert
 * (Ch. X–XI). What to do about it is the caller's hand decision.
 */
export class Hit<TId> {
  constructor(
    readonly id: TId,
    readonly rule: Rule<TId>,
    readonly sourceDistance: number,
    readonly targetDistance: number,
    readonly bits: number,
    readonly rank: number,
  ) {}

  /** The hit's rank, id and bits against the rule it violates, for logs and reports. */
  toString(): string {
    return `#${this.rank} ${String(this.id)}: ${this.bits.toFixed(1)} bits — ${this.rule.toString()}`;
  }
}

/**
 * For every rule, every member of its source whose point on the target ply lies no closer than
 * `targetDeviations` σ below standard distance from the target centroid is a hit. Bits = (bits of the
 * member's own distance to the source centroid) × rule support. Deterministic.
 */
export class Cue {
  /** A cueing instrument using `targetDeviations` (default 1) as the pass/fail line. */
  constructor(readonly targetDeviations = 1) {
    if (targetDeviations < 0) throw new ArgumentOutOfRangeError("targetDeviations");
  }

  /**
   * @param rules Confirmed rules.
   * @param plies Each ply's points by id, keyed by ply name.
   * @param order Tie-break order for ids at equal bits.
   */
  find<TId>(rules: readonly Rule<TId>[], plies: ReadonlyMap<string, ReadonlyMap<TId, Correlithm>>, order: Compare<TId> = defaultCompare): Hit<TId>[] {
    const hits: Omit<Hit<TId>, "rank" | "toString">[] = [];
    for (const rule of rules) {
      const sourcePoints = plies.get(rule.sourcePly);
      if (sourcePoints === undefined) throw new ArgumentError(`No points for ply '${rule.sourcePly}'.`, "plies");
      const targetPoints = plies.get(rule.targetPly);
      if (targetPoints === undefined) throw new ArgumentError(`No points for ply '${rule.targetPly}'.`, "plies");
      const n = rule.target.centroid.dimensions;
      const farEnough = NCube.distanceAtDeviations(n, this.targetDeviations);
      for (const id of rule.source.members) {
        const tp = targetPoints.get(id);
        const sp = sourcePoints.get(id);
        if (tp === undefined || sp === undefined) continue;
        const targetDistance = tp.distanceTo(rule.target.centroid);
        if (targetDistance < farEnough) continue;
        const sourceDistance = sp.distanceTo(rule.source.centroid);
        const bits = NCube.bitContent(sp.dimensions, sourceDistance) * rule.support;
        hits.push({ id, rule, sourceDistance, targetDistance, bits });
      }
    }
    return hits
      .sort((a, b) => (a.bits > b.bits ? -1 : a.bits < b.bits ? 1 : order(a.id, b.id)))
      .map((h, i) => new Hit(h.id, h.rule, h.sourceDistance, h.targetDistance, h.bits, i + 1));
  }
}
