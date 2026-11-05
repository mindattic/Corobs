"""Scores any way of relating things against any other on the same ground truth."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Callable, Collection, Hashable, Iterable, Optional, Sequence, TypeVar

from .seeding import SeededPrng

__all__ = ["RecallResult", "ReachResult", "holdout_recall", "reach", "cascade_yield"]

TId = TypeVar("TId")


@dataclass(frozen=True)
class RecallResult:
    """How well a neighbour function recovers relationships hidden from it."""

    hidden: int
    recovered: int
    predicted: int
    predicted_true: int

    @property
    def recall(self) -> float:
        """Share of the hidden pairs the predictor recovered."""
        return 0.0 if self.hidden == 0 else self.recovered / self.hidden

    @property
    def precision(self) -> float:
        """Share of the predictor's guesses that are true pairs anywhere in the full truth."""
        return 0.0 if self.predicted == 0 else self.predicted_true / self.predicted


@dataclass(frozen=True)
class ReachResult:
    """Mean reachable count per hop, and how many things reach nothing (dead records)."""

    mean_reachable_by_hop: tuple[float, ...]
    isolated: int
    total: int


def _identity(x: Any) -> Any:
    return x


def _ordinal_text(v: Any) -> bytes:
    # C# string.CompareOrdinal(a.ToString(), b.ToString()): UTF-16 code unit order.
    return str(v).encode("utf-16-be", "surrogatepass")


def _canon(a: TId, b: TId) -> tuple[TId, TId]:
    return (a, b) if _ordinal_text(a) <= _ordinal_text(b) else (b, a)


def holdout_recall(
    true_pairs: Sequence[tuple[TId, TId]],
    holdout_fraction: float,
    seed: int,
    neighbours: Callable[[TId], Iterable[TId]],
    key: Optional[Callable[[TId], Hashable]] = None,
) -> RecallResult:
    """Hide ``holdout_fraction`` of the distinct true relationships (deterministically, by seed),
    ask the predictor for each hidden endpoint's neighbours, and count the hidden pairs that come
    back. A relationship is an unordered pair under ``key`` (equality; identity when omitted)."""
    if not (0 < holdout_fraction < 1):
        raise ValueError("holdout_fraction must lie in (0, 1)")
    k = key or _identity

    def pair_key(p: tuple[TId, TId]) -> frozenset:
        return frozenset((k(p[0]), k(p[1])))

    truth = {pair_key(_canon(a, b)) for a, b in true_pairs}

    # COR-T4 (docs/BUGS.md): a pair listed twice, or both ways round, is one relationship to hide.
    distinct: dict[frozenset, tuple[TId, TId]] = {}
    for a, b in true_pairs:
        c = _canon(a, b)
        distinct.setdefault(pair_key(c), c)
    shuffled = list(distinct.values())

    prng = SeededPrng(seed)
    for i in range(len(shuffled) - 1, 0, -1):
        j = prng.next_int(i + 1)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    hidden = [_canon(a, b) for a, b in shuffled[: int(round(len(shuffled) * holdout_fraction))]]
    hidden_set = {pair_key(p) for p in hidden}

    endpoints: dict[Hashable, TId] = {}
    for a, b in hidden:
        endpoints.setdefault(k(a), a)
        endpoints.setdefault(k(b), b)

    recovered = predicted = predicted_true = 0
    seen: set[frozenset] = set()
    for e in endpoints.values():
        for nb in neighbours(e):
            pk = pair_key(_canon(e, nb))
            if pk in seen:
                continue
            seen.add(pk)
            predicted += 1
            if pk in truth:
                predicted_true += 1
            if pk in hidden_set:
                hidden_set.remove(pk)
                recovered += 1
    return RecallResult(len(hidden), recovered, predicted, predicted_true)


def reach(
    ids: Collection[TId],
    adjacency: Callable[[TId], Iterable[TId]],
    max_hops: int,
    key: Optional[Callable[[TId], Hashable]] = None,
) -> ReachResult:
    """Breadth-first reach from every id through ``adjacency``, up to ``max_hops``."""
    if max_hops <= 0:
        raise ValueError("max_hops must be positive")
    k = key or _identity
    sums = [0.0] * max_hops
    isolated = 0
    for start in ids:
        visited = {k(start)}
        frontier = [start]
        reached = 0
        for hop in range(max_hops):
            nxt = []
            for f in frontier:
                for a in adjacency(f):
                    ka = k(a)
                    if ka not in visited:
                        visited.add(ka)
                        nxt.append(a)
            reached += len(nxt)
            sums[hop] += reached
            frontier = nxt
            if not nxt:
                for h in range(hop + 1, max_hops):
                    sums[h] += reached
                break
        if reached == 0:
            isolated += 1
    count = len(ids)
    return ReachResult(tuple(0.0 if count == 0 else s / count for s in sums), isolated, count)


def cascade_yield(closed_by_cascade: int, direct_fixes: int) -> float:
    """Hits closed because something else was fixed, per direct fix (0 when there were none)."""
    return 0.0 if direct_fixes == 0 else closed_by_cascade / direct_fixes
