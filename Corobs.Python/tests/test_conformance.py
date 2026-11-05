"""conformance/vectors.json: the C# reference's exact outputs. Hex strings are compared bit for bit;
JSON numbers (log/pow statistics) to 1e-12 relative. See conformance/README.md."""

import json
import math
import struct
from pathlib import Path

import pytest

from corobs import (CardinalConverter, ContinuousConverter, Correlithm, Cue, NCube, OrdinalConverter,
                    PatternMiner, PlanarConverter, PlyPoint, RuleMiner, SeededPrng, StringCo,
                    cascade_yield, holdout_recall, reach)

VECTORS = json.loads((Path(__file__).resolve().parents[2] / "conformance" / "vectors.json").read_text(encoding="utf-8"))


def hx(x: float) -> str:
    return format(struct.unpack("<Q", struct.pack("<d", x))[0], "016x")


def fx(h: str) -> float:
    return struct.unpack("<d", struct.pack("<Q", int(h, 16)))[0]


def pts(p: Correlithm) -> list[str]:
    return [hx(v) for v in p.coordinates]


def close(actual: float, expected: float) -> None:
    assert math.isclose(actual, expected, rel_tol=1e-12, abs_tol=1e-300), f"{actual!r} != {expected!r}"


def to_point(hexes: list[str]) -> Correlithm:
    return Correlithm([fx(h) for h in hexes])


def test_format():
    assert VECTORS["format"] == 1


@pytest.mark.parametrize("case", VECTORS["prng"], ids=lambda c: c["seed"])
def test_prng(case):
    seed = int(case["seed"])
    u = SeededPrng(seed)
    assert [str(u.next_uint64()) for _ in range(8)] == case["uint64"]
    d = SeededPrng(seed)
    assert [hx(d.next_double()) for _ in range(8)] == case["doubles"]
    for nxt in case["next"]:
        p = SeededPrng(seed)
        assert [p.next_int(nxt["max"]) for _ in range(8)] == nxt["values"], f"max {nxt['max']}"


@pytest.mark.parametrize("case", VECTORS["derive"], ids=lambda c: f"{c['seed']}:{c['label']!r}")
def test_derive(case):
    child = SeededPrng(int(case["seed"])).derive(case["label"])
    assert str(child.seed) == case["childSeed"]
    assert str(child.derive("x").seed) == case["grandchildSeed"]
    assert str(child.next_uint64()) == case["firstUint64"]


def test_ncube():
    v = VECTORS["ncube"]
    close(NCube.STANDARD_DEVIATION, v["standardDeviation"])
    close(NCube.RADIUS_DEVIATION, v["radiusDeviation"])
    close(NCube.DIAMETER_DEVIATION, v["diameterDeviation"])
    for c in v["cases"]:
        n = c["n"]
        close(NCube.standard_distance(n), c["standardDistance"])
        close(NCube.standard_radius(n), c["standardRadius"])
        close(NCube.standard_diameter(n), c["standardDiameter"])
        close(NCube.corner_distance(n), c["cornerDistance"])
        close(NCube.half_diagonal(n), c["halfDiagonal"])
        close(NCube.major_diagonal(n), c["majorDiagonal"])
        for d in c["distances"]:
            x = d["distance"]
            close(NCube.deviations_below(n, x), d["deviationsBelow"])
            close(NCube.bit_content(n, x), d["bitContent"])
            close(NCube.probability_of_proximity(n, x), d["probabilityOfProximity"])
            close(NCube.point_capacity(n, x), d["pointCapacity"])
        for b in c["bitsToDistance"]:
            close(NCube.distance_for_bits(n, b["bits"]), b["distanceForBits"])
        for k in c["distanceAtDeviations"]:
            close(NCube.distance_at_deviations(n, k["deviations"]), k["distance"])


def test_correlithm():
    v = VECTORS["correlithm"]
    prng = SeededPrng(int(v["seed"]))
    n = v["dimensions"]
    a, b = Correlithm.random(prng, n), Correlithm.random(prng, n)
    mid = Correlithm.midpoint(n)
    assert pts(a) == v["a"]
    assert pts(b) == v["b"]
    assert pts(mid) == v["midpoint"]
    assert hx(a.squared_distance_to(b)) == v["squaredDistance"]
    assert hx(a.distance_to(b)) == v["distance"]
    assert pts(Correlithm.centroid([a, b, mid])) == v["centroidOfABMidpoint"]
    for c in v["interpolate"]:
        assert pts(a.interpolate(b, c["fraction"])) == c["point"], f"fraction {c['fraction']}"


def test_strings():
    v = VECTORS["strings"]
    n = v["dimensions"]
    line = StringCo.line(SeededPrng(int(v["line"]["seed"])), n)
    for c in v["line"]["at"]:
        assert pts(line.at(fx(c["t"]))) == c["point"], f"line t={fx(c['t'])}"
    for c in v["line"]["atIndex"] + v["line"]["atIndexSingle"]:
        assert pts(line.at_index(c["index"], c["count"])) == c["point"]
    ring = StringCo.ring(SeededPrng(int(v["ring"]["seed"])), n)
    for c in v["ring"]["at"]:
        assert pts(ring.at(fx(c["t"]))) == c["point"], f"ring t={fx(c['t'])}"
    for c in v["ring"]["atIndex"]:
        assert pts(ring.at_index(c["index"], c["count"])) == c["point"]
    plane = StringCo.plane(SeededPrng(int(v["plane"]["seed"])), n)
    for c in v["plane"]["at"]:
        assert pts(plane.at_xy(fx(c["x"]), fx(c["y"]))) == c["point"], f"plane ({fx(c['x'])}, {fx(c['y'])})"


def test_converters():
    v = VECTORS["converters"]
    n = v["dimensions"]
    assert pts(Correlithm.midpoint(n)) == v["missing"]

    cardinal = CardinalConverter(SeededPrng(int(v["cardinal"]["seed"])), n)
    for c in v["cardinal"]["cases"]:
        assert pts(cardinal.convert(c["value"])) == c["point"], f"cardinal {c['value']!r}"

    ordinal = OrdinalConverter(SeededPrng(int(v["ordinal"]["seed"])), n, v["ordinal"]["order"])
    for c in v["ordinal"]["cases"]:
        assert pts(ordinal.convert(c["value"])) == c["point"], f"ordinal {c['value']}"

    for name in ("continuousLine", "continuousRing"):
        s = v[name]
        conv = ContinuousConverter(SeededPrng(int(s["seed"])), n, s["min"], s["max"], wraps=s["wraps"])
        for c in s["cases"]:
            assert pts(conv.convert(fx(c["value"]))) == c["point"], f"{name} {fx(c['value'])}"

    s = v["planar"]
    planar = PlanarConverter(SeededPrng(int(s["seed"])), n, s["minX"], s["maxX"], s["minY"], s["maxY"])
    for c in s["cases"]:
        assert pts(planar.convert((fx(c["x"]), fx(c["y"])))) == c["point"], f"planar ({fx(c['x'])}, {fx(c['y'])})"


def test_mining():
    v = VECTORS["mining"]
    plies = {name: {p["id"]: to_point(p["point"]) for p in points} for name, points in v["plies"].items()}
    miner = PatternMiner(v["patternMiner"]["minDeviations"], v["patternMiner"]["minMembers"])
    patterns = {name: miner.mine([PlyPoint(i, p) for i, p in ply.items()]) for name, ply in plies.items()}

    for name, expected in v["patterns"].items():
        actual = patterns[name]
        assert len(actual) == len(expected), name
        for a, e in zip(actual, expected):
            assert list(a.members) == e["members"]
            assert pts(a.centroid) == e["centroid"]
            assert hx(a.radius) == e["radius"]
            assert hx(a.mean_pair_distance) == e["meanPairDistance"]
            close(a.bits, e["bits"])

    rules = RuleMiner(v["ruleMiner"]["minSupport"]).mine("faction", patterns["faction"], "turf", patterns["turf"])
    assert len(rules) == len(v["rules"])
    for r, e in zip(rules, v["rules"]):
        assert r.source_ply == e["sourcePly"] and r.target_ply == e["targetPly"]
        assert r.source is patterns[e["sourcePly"]][e["sourcePattern"]]
        assert r.target is patterns[e["targetPly"]][e["targetPattern"]]
        close(r.support, e["support"])
        close(r.bits, e["bits"])

    hits = Cue(v["cue"]["targetDeviations"]).find(rules, plies)
    assert len(hits) == len(v["hits"])
    for h, e in zip(hits, v["hits"]):
        assert h.id == e["id"]
        assert h.rule is rules[e["rule"]]
        assert hx(h.source_distance) == e["sourceDistance"]
        assert hx(h.target_distance) == e["targetDistance"]
        close(h.bits, e["bits"])
        assert h.rank == e["rank"]


def test_bench():
    v = VECTORS["bench"]
    pairs = [(a, b) for a, b in v["pairs"]]
    predictors = {name: {int(k): ids for k, ids in table.items()} for name, table in v["predictors"].items()}
    for c in v["holdoutRecall"]:
        table = predictors[c["predictor"]]
        r = holdout_recall(pairs, c["holdoutFraction"], int(c["seed"]), lambda i, t=table: t.get(i, []))
        e = c["result"]
        assert (r.hidden, r.recovered, r.predicted, r.predicted_true) == (
            e["hidden"], e["recovered"], e["predicted"], e["predictedTrue"]), f"{c['predictor']} {c['holdoutFraction']}"

    rv = v["reach"]
    adjacency = {int(k): ids for k, ids in rv["adjacency"].items()}
    r = reach(list(adjacency), lambda i: adjacency[i], rv["maxHops"])
    assert len(r.mean_reachable_by_hop) == len(rv["meanReachableByHop"])
    for a, e in zip(r.mean_reachable_by_hop, rv["meanReachableByHop"]):
        close(a, e)
    assert (r.isolated, r.total) == (rv["isolated"], rv["total"])

    for c in v["cascadeYield"]:
        close(cascade_yield(c["closedByCascade"], c["directFixes"]), c["yield"])
