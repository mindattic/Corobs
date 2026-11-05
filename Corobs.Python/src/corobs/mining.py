"""Pattern and rule mining, and cueing (Ch. IV, X-XI). Measurement, never judgment."""

from __future__ import annotations

from dataclasses import dataclass, replace
from typing import Any, Callable, Generic, Hashable, Mapping, Optional, Sequence, TypeVar

from .geometry import Correlithm, NCube

__all__ = ["PlyPoint", "Pattern", "PatternMiner", "Rule", "RuleMiner", "Hit", "Cue"]

TId = TypeVar("TId", bound=Hashable)


def _identity(x: Any) -> Any:
    return x


@dataclass(frozen=True)
class PlyPoint(Generic[TId]):
    """One thing's position on one ply (subspace)."""

    id: TId
    point: Correlithm


class Pattern(Generic[TId]):
    """An emergent truth: things whose points on one ply lie far closer together than chance allows.
    What it means, and whether it is true, is the caller's decision."""

    __slots__ = ("members", "centroid", "radius", "mean_pair_distance", "bits", "_key", "_set")

    def __init__(
        self,
        members: Sequence[TId],
        centroid: Correlithm,
        radius: float,
        mean_pair_distance: float,
        bits: float,
        key: Optional[Callable[[TId], Hashable]] = None,
    ) -> None:
        self.members: tuple[TId, ...] = tuple(members)
        """The ids of the things in this cluster."""
        self.centroid = centroid
        """The members' mean point."""
        self.radius = radius
        """The furthest any member lies from the centroid."""
        self.mean_pair_distance = mean_pair_distance
        """The mean distance between members, pairwise."""
        self.bits = bits
        """Eq. III-H bits of the mean pair distance."""
        self._key = key or _identity
        self._set = {self._key(m) for m in self.members}

    def contains(self, id: TId) -> bool:
        """Whether ``id`` is one of this pattern's members."""
        return self._key(id) in self._set

    def __contains__(self, id: object) -> bool:
        return self.contains(id)  # type: ignore[arg-type]

    def __repr__(self) -> str:
        return f"Pattern[{len(self.members)} members, {self.bits:.1f} bits]"


class PatternMiner:
    """Finds clusters on one ply far tighter than chance: two points are linked when they lie at
    least ``min_deviations`` sigma below standard distance (about 52 bits at 6 sigma, Eq. III-H),
    linked points join by union-find, and a component of at least ``min_members`` is a pattern.
    Deterministic: points are processed in id order; output ordered by bits, then first member."""

    def __init__(self, min_deviations: float = 6, min_members: int = 5) -> None:
        if min_deviations <= 0:
            raise ValueError("min_deviations must be positive")
        if min_members < 2:
            raise ValueError("min_members must be at least 2")
        self.min_deviations = float(min_deviations)
        self.min_members = min_members

    def mine(
        self,
        points: Sequence[PlyPoint[TId]],
        order: Optional[Callable[[TId], Any]] = None,
        key: Optional[Callable[[TId], Hashable]] = None,
    ) -> list[Pattern[TId]]:
        """The patterns among ``points`` (all on one ply). ``order`` is a sort key for ids (natural
        order when omitted); ``key`` is the equality key passed to each pattern."""
        if len(points) < self.min_members:
            return []
        n = points[0].point.dimensions
        sort_key = order or _identity
        ordered = sorted(points, key=lambda p: sort_key(p.id))
        threshold = NCube.distance_at_deviations(n, self.min_deviations)
        if threshold < 0:
            # COR-T4 (docs/BUGS.md): distance is never negative, so a negative threshold links nothing.
            return []
        threshold_sq = threshold * threshold

        parent = list(range(len(ordered)))
        coords = [p.point.coordinates for p in ordered]
        for i in range(len(ordered)):
            ci = coords[i]
            for j in range(i + 1, len(ordered)):
                if _within(ci, coords[j], threshold_sq):
                    _union(parent, i, j)

        groups: dict[int, list[int]] = {}
        for i in range(len(ordered)):
            groups.setdefault(_find(parent, i), []).append(i)

        result: list[Pattern[TId]] = []
        for members in groups.values():
            if len(members) < self.min_members:
                continue
            pts = [ordered[i].point for i in members]
            centroid = Correlithm.centroid(pts)
            radius = max(p.distance_to(centroid) for p in pts)
            total = 0.0
            pairs = 0
            for a in range(len(pts)):
                for b in range(a + 1, len(pts)):
                    total += pts[a].distance_to(pts[b])
                    pairs += 1
            mean = total / pairs
            result.append(Pattern([ordered[i].id for i in members], centroid, radius, mean, NCube.bit_content(n, mean), key))

        result.sort(key=lambda p: sort_key(p.members[0]))
        result.sort(key=lambda p: p.bits, reverse=True)
        return result


def _within(a: Sequence[float], b: Sequence[float], limit: float) -> bool:
    # Same left-to-right sum as Correlithm.squared_distance_to; terms are non-negative, so the partial
    # sum never decreases and passing the limit early is final.
    if len(a) != len(b):
        raise ValueError("Points from different spaces have no distance.")
    s = 0.0
    for x, y in zip(a, b):
        d = x - y
        s += d * d
        if s > limit:
            return False
    return True


def _find(parent: list[int], i: int) -> int:
    while parent[i] != i:
        parent[i] = parent[parent[i]]
        i = parent[i]
    return i


def _union(parent: list[int], a: int, b: int) -> None:
    ra, rb = _find(parent, a), _find(parent, b)
    if ra == rb:
        return
    if ra < rb:
        parent[rb] = ra
    else:
        parent[ra] = rb


@dataclass(frozen=True)
class Rule(Generic[TId]):
    """A rule ``s.p >: t.q`` (Ch. IV): things inside pattern ``source`` on ``source_ply`` are found
    inside pattern ``target`` on ``target_ply`` with the given support."""

    source_ply: str
    source: Pattern[TId]
    target_ply: str
    target: Pattern[TId]
    support: float
    bits: float

    def __str__(self) -> str:
        return (f"{self.source_ply}.[{len(self.source.members)}] >: {self.target_ply}.[{len(self.target.members)}]"
                f" support {self.support:.0%}, {self.bits:.1f} bits")


class RuleMiner:
    """Proposes rules between two plies' patterns: for each source pattern, the target pattern
    holding the largest share of its members, kept when that share reaches ``min_support``.
    Bits = support x the source pattern's bits. Deterministic."""

    def __init__(self, min_support: float = 0.8) -> None:
        if min_support <= 0 or min_support > 1:
            raise ValueError("min_support must lie in (0, 1]")
        self.min_support = float(min_support)

    def mine(
        self,
        source_ply: str,
        source: Sequence[Pattern[TId]],
        target_ply: str,
        target: Sequence[Pattern[TId]],
    ) -> list[Rule[TId]]:
        """Rules from ``source_ply``'s patterns to ``target_ply``'s, ordered by bits descending."""
        if source_ply == target_ply:
            raise ValueError("A rule relates two different plies.")
        rules: list[Rule[TId]] = []
        for p in source:
            best: Optional[Pattern[TId]] = None
            best_count = 0
            for q in target:
                count = sum(1 for m in p.members if q.contains(m))
                if count > best_count:
                    best, best_count = q, count
            if best is None:
                continue
            support = best_count / len(p.members)
            if support >= self.min_support:
                rules.append(Rule(source_ply, p, target_ply, best, support, support * p.bits))
        rules.sort(key=lambda r: r.bits, reverse=True)
        return rules


@dataclass(frozen=True)
class Hit(Generic[TId]):
    """A ranked contradiction candidate: inside a rule's source, yet far from its target (Ch. X-XI).
    What to do about it is the caller's decision."""

    id: TId
    rule: Rule[TId]
    source_distance: float
    target_distance: float
    bits: float
    rank: int

    def __str__(self) -> str:
        return f"#{self.rank} {self.id}: {self.bits:.1f} bits - {self.rule}"


class Cue:
    """For every rule, every source member whose target-ply point lies no closer than
    ``target_deviations`` sigma below standard distance from the target centroid is a hit.
    Bits = bits of the member's distance to the source centroid x rule support. Deterministic."""

    def __init__(self, target_deviations: float = 1) -> None:
        if target_deviations < 0:
            raise ValueError("target_deviations must not be negative")
        self.target_deviations = float(target_deviations)

    def find(
        self,
        rules: Sequence[Rule[TId]],
        plies: Mapping[str, Mapping[TId, Correlithm]],
        order: Optional[Callable[[TId], Any]] = None,
    ) -> list[Hit[TId]]:
        """Hits for ``rules`` given each ply's points by id; ``order`` breaks ties at equal bits."""
        sort_key = order or _identity
        hits: list[Hit[TId]] = []
        for rule in rules:
            if rule.source_ply not in plies:
                raise ValueError(f"No points for ply '{rule.source_ply}'.")
            if rule.target_ply not in plies:
                raise ValueError(f"No points for ply '{rule.target_ply}'.")
            source_points, target_points = plies[rule.source_ply], plies[rule.target_ply]
            n = rule.target.centroid.dimensions
            far_enough = NCube.distance_at_deviations(n, self.target_deviations)
            for id in rule.source.members:
                tp = target_points.get(id)
                sp = source_points.get(id)
                if tp is None or sp is None:
                    continue
                target_distance = tp.distance_to(rule.target.centroid)
                if target_distance < far_enough:
                    continue
                source_distance = sp.distance_to(rule.source.centroid)
                bits = NCube.bit_content(sp.dimensions, source_distance) * rule.support
                hits.append(Hit(id, rule, source_distance, target_distance, bits, 0))
        hits.sort(key=lambda h: sort_key(h.id))
        hits.sort(key=lambda h: h.bits, reverse=True)
        return [replace(h, rank=i + 1) for i, h in enumerate(hits)]
