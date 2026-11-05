"""The unit N-cube's statistics (Ch. II-III) and the correlithm object, a point in it."""

from __future__ import annotations

import math
from typing import Iterable, Sequence

from .seeding import SeededPrng

__all__ = ["NCube", "Correlithm"]

_LN2 = math.log(2)


def _check(dimensions: int) -> int:
    if dimensions <= 0:
        raise ValueError("A space needs at least one dimension; the statistics hold from about 20.")
    return dimensions


class NCube:
    """The statistics of the real unit N-cube (Lawrence, *Correlithm Object Technology*, Ch. II-III).

    Two random points are almost always :meth:`standard_distance` apart, with a standard deviation
    that does not grow with N (Table II-1). Proximity far below that distance is information:
    :meth:`bit_content` says how much (Eq. III-H), :meth:`probability_of_proximity` how unlikely by
    chance (Eq. III-J), :meth:`point_capacity` how many random points fit before two collide (Eq. III-Q).
    """

    STANDARD_DEVIATION = 0.24152294576982397
    """sigma of the distance between two random points: sqrt(7/120), independent of N."""
    RADIUS_DEVIATION = 0.12909944487358055
    """sigma of the distance from the midpoint to a random point: sqrt(1/60)."""
    DIAMETER_DEVIATION = 0.2581988897471611
    """sigma of the distance from a corner to a random point: sqrt(1/15)."""

    @staticmethod
    def standard_distance(dimensions: int) -> float:
        """mu: expected distance between two random points, sqrt(N/6)."""
        return math.sqrt(_check(dimensions) / 6.0)

    @staticmethod
    def standard_radius(dimensions: int) -> float:
        """Expected distance from the midpoint to a random point, sqrt(N/12)."""
        return math.sqrt(_check(dimensions) / 12.0)

    @staticmethod
    def standard_diameter(dimensions: int) -> float:
        """Expected distance from a corner to a random point, sqrt(N/3)."""
        return math.sqrt(_check(dimensions) / 3.0)

    @staticmethod
    def corner_distance(dimensions: int) -> float:
        """Expected distance between two random corners, sqrt(N/2)."""
        return math.sqrt(_check(dimensions) / 2.0)

    @staticmethod
    def half_diagonal(dimensions: int) -> float:
        """Midpoint to any corner, exactly sqrt(N/4)."""
        return math.sqrt(_check(dimensions) / 4.0)

    @staticmethod
    def major_diagonal(dimensions: int) -> float:
        """Opposite corners, exactly sqrt(N)."""
        return math.sqrt(float(_check(dimensions)))

    @staticmethod
    def deviations_below(dimensions: int, distance: float) -> float:
        """How many standard deviations below mu a distance lies (negative when beyond mu)."""
        return (NCube.standard_distance(dimensions) - distance) / NCube.STANDARD_DEVIATION

    @staticmethod
    def distance_at_deviations(dimensions: int, deviations: float) -> float:
        """The distance that lies ``deviations`` sigma below mu."""
        return NCube.standard_distance(dimensions) - deviations * NCube.STANDARD_DEVIATION

    @staticmethod
    def bit_content(dimensions: int, distance: float) -> float:
        """Eq. III-H: bits in two points lying ``distance`` apart, ((mu - d)/sigma)^2 / ln 2.
        Zero at or beyond standard distance."""
        x = NCube.deviations_below(dimensions, distance)
        return 0.0 if x <= 0 else x * x / _LN2

    @staticmethod
    def distance_for_bits(dimensions: int, bits: float) -> float:
        """The distance at which proximity is worth ``bits`` bits."""
        if bits < 0:
            raise ValueError("bits must not be negative")
        return NCube.standard_distance(dimensions) - NCube.STANDARD_DEVIATION * math.sqrt(bits * _LN2)

    @staticmethod
    def probability_of_proximity(dimensions: int, distance: float) -> float:
        """Eq. III-J: probability that two random points lie closer than ``distance``, 2^(-bits)."""
        return math.pow(2.0, -NCube.bit_content(dimensions, distance))

    @staticmethod
    def point_capacity(dimensions: int, distance: float) -> float:
        """Eq. III-Q: random points placeable before two are expected closer than ``distance``,
        10^(3.7 (mu - d)^2)."""
        gap = NCube.standard_distance(dimensions) - distance
        return 1.0 if gap <= 0 else math.pow(10.0, 3.7 * gap * gap)


class Correlithm:
    """A correlithm object: one point in the real unit N-cube, every coordinate in [0, 1].

    A CO is a *soft token* (Ch. IV): it stands for its datum exactly at its coordinates and, to a
    degree :meth:`NCube.bit_content` quantifies, at every point nearby. Immutable.
    """

    __slots__ = ("_c",)

    def __init__(self, coordinates: Iterable[float]) -> None:
        c = tuple(float(v) for v in coordinates)
        if not c:
            raise ValueError("A point needs at least one coordinate.")
        for v in c:
            if math.isnan(v) or v < 0 or v > 1:
                raise ValueError("Every coordinate must lie in [0, 1].")
        self._c = c

    @classmethod
    def _owned(cls, c: Sequence[float]) -> "Correlithm":
        obj = cls.__new__(cls)
        obj._c = tuple(c)
        return obj

    @property
    def dimensions(self) -> int:
        """N: the dimensionality of the cube this point lives in."""
        return len(self._c)

    @property
    def coordinates(self) -> tuple[float, ...]:
        """All N coordinates, in order."""
        return self._c

    def __getitem__(self, dimension: int) -> float:
        return self._c[dimension]

    def __len__(self) -> int:
        return len(self._c)

    @staticmethod
    def random(prng: SeededPrng, dimensions: int) -> "Correlithm":
        """A point drawn uniformly from the whole cube: a fresh token."""
        n = _check(dimensions)
        return Correlithm._owned([prng.next_double() for _ in range(n)])

    @staticmethod
    def midpoint(dimensions: int) -> "Correlithm":
        """The cube's centre, 0.5 in every dimension: where a missing value goes (carries no bits)."""
        return Correlithm._owned([0.5] * _check(dimensions))

    def squared_distance_to(self, other: "Correlithm") -> float:
        """Euclidean distance squared to ``other``, summed left to right."""
        self._check_same(other)
        s = 0.0
        for x, y in zip(self._c, other._c):
            d = x - y
            s += d * d
        return s

    def distance_to(self, other: "Correlithm") -> float:
        """Euclidean distance to ``other``; compare against :meth:`NCube.standard_distance`."""
        return math.sqrt(self.squared_distance_to(other))

    def interpolate(self, other: "Correlithm", fraction: float) -> "Correlithm":
        """Linear interpolation toward ``other``. Ch. VII warns interpolated points "take a
        shortcut"; use :class:`corobs.strings.StringCo` for sequences."""
        self._check_same(other)
        if fraction < 0 or fraction > 1:
            raise ValueError("fraction must lie in [0, 1]")
        return Correlithm._owned([a + (b - a) * fraction for a, b in zip(self._c, other._c)])

    @staticmethod
    def centroid(points: Sequence["Correlithm"]) -> "Correlithm":
        """The coordinate-wise mean of a set of points."""
        if len(points) == 0:
            raise ValueError("A centroid needs at least one point.")
        total: list[float] | None = None
        for p in points:
            if total is None:
                total = [0.0] * p.dimensions
            if len(total) != p.dimensions:
                raise ValueError("All points must share one dimensionality.")
            c = p._c
            for i in range(len(total)):
                total[i] += c[i]
        assert total is not None
        count = len(points)
        return Correlithm._owned([v / count for v in total])

    @staticmethod
    def superpose(points: Sequence["Correlithm"]) -> "Correlithm":
        """A point that superposes several: their centroid (Ch. VIII, Superposition)."""
        return Correlithm.centroid(points)

    def __eq__(self, other: object) -> bool:
        return isinstance(other, Correlithm) and self._c == other._c

    def __hash__(self) -> int:
        return hash(self._c)

    def __repr__(self) -> str:
        return f"CO[{self.dimensions}]"

    def _check_same(self, other: "Correlithm") -> None:
        if len(other._c) != len(self._c):
            raise ValueError("Points from different spaces have no distance.")
