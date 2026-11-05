from collections import defaultdict

import pytest

from corobs import cascade_yield, holdout_recall, reach


def test_holdout_recall_counts_hidden_pairs_the_predictor_recovers():
    pairs = [(f"a{i}", f"b{i}") for i in range(20)]
    # A predictor that knows every pair recovers everything with perfect precision.
    everything = defaultdict(list)
    for a, b in pairs:
        everything[a].append(b)
        everything[b].append(a)
    perfect = holdout_recall(pairs, 0.25, 1, lambda i: everything[i])
    assert perfect.hidden == 5
    assert perfect.recall == 1
    assert perfect.precision == 1
    # A predictor that knows nothing recovers nothing.
    blind = holdout_recall(pairs, 0.25, 1, lambda _: [])
    assert blind.recall == 0
    # Same seed, same hidden set.
    assert holdout_recall(pairs, 0.25, 1, lambda _: []).hidden == blind.hidden
    with pytest.raises(ValueError):
        holdout_recall(pairs, 1.0, 1, lambda _: [])


def test_reach_counts_hops_and_isolated_records():
    adj = {1: [2], 2: [1, 3], 3: [2], 4: []}
    r = reach([1, 2, 3, 4], lambda i: adj[i], max_hops=2)
    assert r.isolated == 1
    assert r.total == 4
    assert r.mean_reachable_by_hop[0] == (1 + 2 + 1 + 0) / 4
    assert r.mean_reachable_by_hop[1] == (2 + 2 + 2 + 0) / 4
    with pytest.raises(ValueError):
        reach([1], lambda i: [], 0)


def test_cascade_yield_is_closed_by_cascade_per_direct_fix():
    assert cascade_yield(6, 4) == 1.5
    assert cascade_yield(0, 0) == 0
