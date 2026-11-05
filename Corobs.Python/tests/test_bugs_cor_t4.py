"""COR-T4 invariants (docs/BUGS.md). The reference keeps the old code; this port carries only the
fix, so these pass and pin the invariant."""

import math

import pytest

from corobs import Correlithm, NCube, PatternMiner, PlyPoint, SeededPrng, StringCo, holdout_recall


def test_threshold_no_pattern_member_is_linked_by_a_pair_short_of_the_required_sigma():
    n = 4
    miner = PatternMiner(min_deviations=6, min_members=5)
    assert NCube.distance_at_deviations(n, miner.min_deviations) < 0, "precondition: mu - 6 sigma < 0 at N = 4"

    points = [PlyPoint(k, Correlithm([0.1 * k, 0.5, 0.5, 0.5])) for k in range(5)]
    for pattern in miner.mine(points):
        for id in pattern.members:
            p = points[id].point
            best = max(NCube.deviations_below(n, p.distance_to(points[o].point)) for o in pattern.members if o != id)
            assert best >= miner.min_deviations, (
                f"member {id} joined a {miner.min_deviations} sigma pattern though its closest partner is only {best:.2f} sigma below mu")


@pytest.mark.parametrize("t", [math.inf, -math.inf])
def test_ring_at_never_returns_a_point_off_the_ring(t):
    n = 32
    ring = StringCo.ring(SeededPrng(42), n)
    try:
        p = ring.at(t)
    except ValueError:
        return
    # A ring takes exactly 2N distinct points, one per arc between its 2N breakpoints.
    steps = 200_000
    on_ring = {ring.at(k / steps) for k in range(steps)}
    assert len(on_ring) == 2 * n, "precondition: the grid visits every ring point"
    assert p in on_ring, f"at({t}) returned a point the ring never visits (book Ch. IX, p. 123)"


def _oracle(pairs, key=lambda x: x):
    m = {}
    for a, b in pairs:
        m.setdefault(key(a), []).append(b)
        m.setdefault(key(b), []).append(a)
    return lambda i: m.get(key(i), [])


def test_pairs_a_perfect_predictor_recovers_every_hidden_relationship_even_when_listed_repeatedly():
    pairs = []
    for i in range(20):
        pairs += [(2 * i, 2 * i + 1), (2 * i, 2 * i + 1), (2 * i + 1, 2 * i)]
    r = holdout_recall(pairs, 0.5, 7, _oracle(pairs))
    assert r.recall == 1.0, f"perfect predictor scored recall {r.recall:.3f} (hidden {r.hidden}, recovered {r.recovered})"


def test_pairs_one_relationship_under_the_callers_comparer_is_hidden_once():
    pairs = []
    for i in range(20):
        pairs += [(f"a{i}", f"B{i}"), (f"b{i}", f"A{i}")]
    r = holdout_recall(pairs, 0.5, 7, _oracle(pairs, str.lower), key=str.lower)
    assert r.hidden == 10, "20 relationships, half hidden; each spelled two ways is still one relationship"
