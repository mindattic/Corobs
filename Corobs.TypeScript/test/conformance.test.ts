import { describe, expect, it } from "vitest";
import {
  Bench,
  CardinalConverter,
  ContinuousConverter,
  Correlithm,
  Cue,
  NCube,
  OrdinalConverter,
  PatternMiner,
  PlanarConverter,
  RuleMiner,
  SeededPrng,
  StringCo,
  type Pattern,
  type PlyPoint,
} from "../src/index.js";
import { bits, expectClose, fromBits, pointBits, vectors } from "./helpers.js";
/** conformance/vectors.json: the C# reference's exact outputs, reproduced bit for bit. */
describe("conformance with the C# reference", () => {
  it("format", () => expect(vectors.format).toBe(1));

  it("prng", () => {
    for (const c of vectors.prng) {
      const u = new SeededPrng(BigInt(c.seed));
      expect(c.uint64.map(() => u.nextUInt64().toString()), `uint64 seed ${c.seed}`).toEqual(c.uint64);
      const d = new SeededPrng(BigInt(c.seed));
      expect(c.doubles.map(() => bits(d.nextDouble())), `doubles seed ${c.seed}`).toEqual(c.doubles);
      for (const m of c.next) {
        const p = new SeededPrng(BigInt(c.seed));
        expect(m.values.map(() => p.next(m.max)), `next(${m.max}) seed ${c.seed}`).toEqual(m.values);
      }
    }
  });

  it("derive", () => {
    for (const c of vectors.derive) {
      const child = new SeededPrng(BigInt(c.seed)).derive(c.label);
      expect(child.seed.toString(), `derive(${c.seed}, ${JSON.stringify(c.label)})`).toBe(c.childSeed);
      expect(child.nextUInt64().toString()).toBe(c.firstUint64);
      expect(child.derive("x").seed.toString()).toBe(c.grandchildSeed);
    }
  });

  it("ncube", () => {
    const v = vectors.ncube;
    expect(NCube.standardDeviation).toBe(v.standardDeviation);
    expect(NCube.radiusDeviation).toBe(v.radiusDeviation);
    expect(NCube.diameterDeviation).toBe(v.diameterDeviation);
    for (const c of v.cases) {
      const n: number = c.n;
      expectClose(NCube.standardDistance(n), c.standardDistance, `standardDistance ${n}`);
      expectClose(NCube.standardRadius(n), c.standardRadius, `standardRadius ${n}`);
      expectClose(NCube.standardDiameter(n), c.standardDiameter, `standardDiameter ${n}`);
      expectClose(NCube.cornerDistance(n), c.cornerDistance, `cornerDistance ${n}`);
      expectClose(NCube.halfDiagonal(n), c.halfDiagonal, `halfDiagonal ${n}`);
      expectClose(NCube.majorDiagonal(n), c.majorDiagonal, `majorDiagonal ${n}`);
      for (const d of c.distances) {
        expectClose(NCube.deviationsBelow(n, d.distance), d.deviationsBelow, `deviationsBelow ${n} ${d.distance}`);
        expectClose(NCube.bitContent(n, d.distance), d.bitContent, `bitContent ${n} ${d.distance}`);
        expectClose(NCube.probabilityOfProximity(n, d.distance), d.probabilityOfProximity, `probabilityOfProximity ${n} ${d.distance}`);
        expectClose(NCube.pointCapacity(n, d.distance), d.pointCapacity, `pointCapacity ${n} ${d.distance}`);
      }
      for (const b of c.bitsToDistance) expectClose(NCube.distanceForBits(n, b.bits), b.distanceForBits, `distanceForBits ${n} ${b.bits}`);
      for (const k of c.distanceAtDeviations) expectClose(NCube.distanceAtDeviations(n, k.deviations), k.distance, `distanceAtDeviations ${n} ${k.deviations}`);
    }
  });

  it("correlithm", () => {
    const v = vectors.correlithm;
    const prng = new SeededPrng(BigInt(v.seed));
    const a = Correlithm.random(prng, v.dimensions);
    const b = Correlithm.random(prng, v.dimensions);
    const mid = Correlithm.midpoint(v.dimensions);
    expect(pointBits(a)).toEqual(v.a);
    expect(pointBits(b)).toEqual(v.b);
    expect(pointBits(mid)).toEqual(v.midpoint);
    expect(bits(a.squaredDistanceTo(b))).toBe(v.squaredDistance);
    expect(bits(a.distanceTo(b))).toBe(v.distance);
    expect(pointBits(Correlithm.centroid([a, b, mid]))).toEqual(v.centroidOfABMidpoint);
    for (const c of v.interpolate) expect(pointBits(a.interpolate(b, c.fraction)), `interpolate ${c.fraction}`).toEqual(c.point);
  });

  it("strings", () => {
    const v = vectors.strings;
    const line = StringCo.line(new SeededPrng(BigInt(v.line.seed)), v.dimensions);
    for (const c of v.line.at) expect(pointBits(line.at(fromBits(c.t))), `line.at(${fromBits(c.t)})`).toEqual(c.point);
    for (const c of [...v.line.atIndex, ...v.line.atIndexSingle]) expect(pointBits(line.atIndex(c.index, c.count)), `line.atIndex(${c.index}, ${c.count})`).toEqual(c.point);
    const ring = StringCo.ring(new SeededPrng(BigInt(v.ring.seed)), v.dimensions);
    for (const c of v.ring.at) expect(pointBits(ring.at(fromBits(c.t))), `ring.at(${fromBits(c.t)})`).toEqual(c.point);
    for (const c of v.ring.atIndex) expect(pointBits(ring.atIndex(c.index, c.count)), `ring.atIndex(${c.index}, ${c.count})`).toEqual(c.point);
    const plane = StringCo.plane(new SeededPrng(BigInt(v.plane.seed)), v.dimensions);
    for (const c of v.plane.at) expect(pointBits(plane.at(fromBits(c.x), fromBits(c.y))), `plane.at(${fromBits(c.x)}, ${fromBits(c.y)})`).toEqual(c.point);
  });

  it("converters", () => {
    const v = vectors.converters;
    const n: number = v.dimensions;
    const missing = Correlithm.midpoint(n);
    expect(pointBits(missing)).toEqual(v.missing);

    const cardinal = new CardinalConverter<string>(new SeededPrng(BigInt(v.cardinal.seed)), n);
    for (const c of v.cardinal.cases) expect(pointBits(cardinal.convert(c.value)), `cardinal ${JSON.stringify(c.value)}`).toEqual(c.point);
    expect(pointBits(cardinal.convert(null))).toEqual(v.missing);

    const ordinal = new OrdinalConverter<string>(new SeededPrng(BigInt(v.ordinal.seed)), n, v.ordinal.order);
    for (const c of v.ordinal.cases) expect(pointBits(ordinal.convert(c.value)), `ordinal ${c.value}`).toEqual(c.point);

    for (const name of ["continuousLine", "continuousRing"]) {
      const s = v[name];
      const conv = new ContinuousConverter(new SeededPrng(BigInt(s.seed)), n, s.min, s.max, s.wraps);
      for (const c of s.cases) expect(pointBits(conv.convert(fromBits(c.value))), `${name} ${fromBits(c.value)}`).toEqual(c.point);
      expect(pointBits(conv.convert(null))).toEqual(v.missing);
    }

    const p = v.planar;
    const planar = new PlanarConverter(new SeededPrng(BigInt(p.seed)), n, p.minX, p.maxX, p.minY, p.maxY);
    for (const c of p.cases) expect(pointBits(planar.convert([fromBits(c.x), fromBits(c.y)])), `planar ${fromBits(c.x)}, ${fromBits(c.y)}`).toEqual(c.point);
  });

  it("mining", () => {
    const v = vectors.mining;
    const ply = (name: string): PlyPoint<number>[] => v.plies[name].map((e: any) => ({ id: e.id, point: new Correlithm(e.point.map(fromBits)) }));
    const faction = ply("faction");
    const turf = ply("turf");
    const miner = new PatternMiner(v.patternMiner.minDeviations, v.patternMiner.minMembers);
    const fp = miner.mine(faction);
    const tp = miner.mine(turf);

    const check = (actual: Pattern<number>[], expected: any[], name: string): void => {
      expect(actual.length, `${name} pattern count`).toBe(expected.length);
      actual.forEach((p, i) => {
        const e = expected[i];
        expect(p.members, `${name}[${i}] members`).toEqual(e.members);
        expect(pointBits(p.centroid), `${name}[${i}] centroid`).toEqual(e.centroid);
        expect(bits(p.radius), `${name}[${i}] radius`).toBe(e.radius);
        expect(bits(p.meanPairDistance), `${name}[${i}] meanPairDistance`).toBe(e.meanPairDistance);
        expectClose(p.bits, e.bits, `${name}[${i}] bits`);
      });
    };
    check(fp, v.patterns.faction, "faction");
    check(tp, v.patterns.turf, "turf");

    const rules = new RuleMiner(v.ruleMiner.minSupport).mine("faction", fp, "turf", tp);
    expect(rules.length, "rule count").toBe(v.rules.length);
    rules.forEach((r, i) => {
      const e = v.rules[i];
      expect(r.sourcePly).toBe(e.sourcePly);
      expect(fp.indexOf(r.source), `rule ${i} source`).toBe(e.sourcePattern);
      expect(r.targetPly).toBe(e.targetPly);
      expect(tp.indexOf(r.target), `rule ${i} target`).toBe(e.targetPattern);
      expectClose(r.support, e.support, `rule ${i} support`);
      expectClose(r.bits, e.bits, `rule ${i} bits`);
    });

    const plies = new Map([
      ["faction", new Map(faction.map((p) => [p.id, p.point] as const))],
      ["turf", new Map(turf.map((p) => [p.id, p.point] as const))],
    ]);
    const hits = new Cue(v.cue.targetDeviations).find(rules, plies);
    expect(hits.length, "hit count").toBe(v.hits.length);
    hits.forEach((h, i) => {
      const e = v.hits[i];
      expect(h.id, `hit ${i} id`).toBe(e.id);
      expect(rules.indexOf(h.rule), `hit ${i} rule`).toBe(e.rule);
      expect(bits(h.sourceDistance), `hit ${i} sourceDistance`).toBe(e.sourceDistance);
      expect(bits(h.targetDistance), `hit ${i} targetDistance`).toBe(e.targetDistance);
      expectClose(h.bits, e.bits, `hit ${i} bits`);
      expect(h.rank).toBe(e.rank);
    });
  });

  it("bench", () => {
    const v = vectors.bench;
    const pairs: [number, number][] = v.pairs;
    for (const c of v.holdoutRecall) {
      const table: Record<string, number[]> = v.predictors[c.predictor];
      const r = Bench.holdoutRecall(pairs, c.holdoutFraction, BigInt(c.seed), (id) => table[String(id)] ?? []);
      const label = `${c.predictor} ${c.holdoutFraction} seed ${c.seed}`;
      expect({ hidden: r.hidden, recovered: r.recovered, predicted: r.predicted, predictedTrue: r.predictedTrue }, label).toEqual(c.result);
    }

    const reach = v.reach;
    const ids = Object.keys(reach.adjacency).map(Number);
    const r = Bench.reach(ids, (id) => reach.adjacency[String(id)] as number[], reach.maxHops);
    expect(r.meanReachableByHop.length).toBe(reach.meanReachableByHop.length);
    r.meanReachableByHop.forEach((m, i) => expectClose(m, reach.meanReachableByHop[i], `reach hop ${i}`));
    expect(r.isolated).toBe(reach.isolated);
    expect(r.total).toBe(reach.total);

    for (const c of v.cascadeYield) expectClose(Bench.cascadeYield(c.closedByCascade, c.directFixes), c.yield, "cascadeYield");
  });
});
