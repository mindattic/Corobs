"""Converters (sensors, Ch. IX): world data into CO space. A missing value is the midpoint."""

from __future__ import annotations

import math
from typing import Callable, Generic, Hashable, Optional, Protocol, Sequence, TypeVar

from .geometry import Correlithm
from .seeding import SeededPrng
from .strings import StringCo

__all__ = ["Converter", "CardinalConverter", "OrdinalConverter", "ContinuousConverter", "PlanarConverter"]

T = TypeVar("T")
T_contra = TypeVar("T_contra", contravariant=True)
H = TypeVar("H", bound=Hashable)


class Converter(Protocol[T_contra]):
    """Moves world data into CO space. ``None`` (and NaN for numbers) converts to :attr:`missing`."""

    @property
    def dimensions(self) -> int: ...

    @property
    def missing(self) -> Correlithm: ...

    def convert(self, value: Optional[T_contra]) -> Correlithm: ...


class CardinalConverter(Generic[T]):
    """A cardinal set (unordered: a faction, a species): each distinct value gets its own random CO,
    derived from the root seed and the value's key, so the mapping is independent of arrival order."""

    def __init__(self, root: SeededPrng, dimensions: int, key: Optional[Callable[[T], str]] = None) -> None:
        self._root = root
        self._key: Callable[[T], str] = key if key is not None else str
        self._cache: dict[str, Correlithm] = {}
        self._dimensions = dimensions
        self._missing = Correlithm.midpoint(dimensions)

    @property
    def dimensions(self) -> int:
        return self._dimensions

    @property
    def missing(self) -> Correlithm:
        return self._missing

    def convert(self, value: Optional[T]) -> Correlithm:
        """The value's CO (created and cached on first use), or :attr:`missing` for ``None``."""
        if value is None:
            return self._missing
        k = self._key(value)
        co = self._cache.get(k)
        if co is None:
            co = Correlithm.random(self._root.derive(k), self._dimensions)
            self._cache[k] = co
        return co


class OrdinalConverter(Generic[H]):
    """An ordinal set (tiers, ranks, an alphabet): evenly spaced positions on a line string CO, so
    neighbours are near and extremes are at standard distance (Fig. VII-8)."""

    def __init__(self, prng: SeededPrng, dimensions: int, order: Sequence[H]) -> None:
        if len(order) == 0:
            raise ValueError("An ordinal set needs at least one value.")
        self._index: dict[H, int] = {}
        for i, v in enumerate(order):
            if v in self._index:
                raise ValueError(f"'{v}' appears twice in the order.")
            self._index[v] = i
        self._line = StringCo.line(prng, dimensions)
        self._dimensions = dimensions
        self._missing = Correlithm.midpoint(dimensions)

    @property
    def dimensions(self) -> int:
        return self._dimensions

    @property
    def missing(self) -> Correlithm:
        return self._missing

    @property
    def count(self) -> int:
        """How many distinct values are in the order."""
        return len(self._index)

    def convert(self, value: Optional[H]) -> Correlithm:
        """The value's position on the line; raises ``ValueError`` for a value outside the set."""
        if value is None:
            return self._missing
        i = self._index.get(value)
        if i is None:
            raise ValueError(f"'{value}' is not in this ordinal set.")
        return self._line.at_index(i, len(self._index))


class ContinuousConverter:
    """A continuous variable on [min, max] mapped onto a line string CO, or a ring when it wraps."""

    def __init__(self, prng: SeededPrng, dimensions: int, min: float, max: float, wraps: bool = False) -> None:
        if not (max > min):
            raise ValueError("max must exceed min.")
        self._string = StringCo.ring(prng, dimensions) if wraps else StringCo.line(prng, dimensions)
        self._min, self._max, self._wraps = float(min), float(max), wraps
        self._dimensions = dimensions
        self._missing = Correlithm.midpoint(dimensions)

    @property
    def dimensions(self) -> int:
        return self._dimensions

    @property
    def missing(self) -> Correlithm:
        return self._missing

    def convert(self, value: Optional[float]) -> Correlithm:
        """The value's point (:attr:`missing` for ``None``, NaN, or an infinite value on a ring)."""
        if value is None or math.isnan(value):
            return self._missing
        if self._wraps and math.isinf(value):
            return self._missing
        t = (value - self._min) / (self._max - self._min)
        return self._string.at(t)


class PlanarConverter:
    """A point in a bounded plane (a map position) on a planar string CO (Fig. VII-10)."""

    def __init__(self, prng: SeededPrng, dimensions: int, min_x: float, max_x: float, min_y: float, max_y: float) -> None:
        if not (max_x > min_x) or not (max_y > min_y):
            raise ValueError("Each axis needs max > min.")
        self._plane = StringCo.plane(prng, dimensions)
        self._min_x, self._max_x = float(min_x), float(max_x)
        self._min_y, self._max_y = float(min_y), float(max_y)
        self._dimensions = dimensions
        self._missing = Correlithm.midpoint(dimensions)

    @property
    def dimensions(self) -> int:
        return self._dimensions

    @property
    def missing(self) -> Correlithm:
        return self._missing

    def convert(self, value: Optional[tuple[float, float]]) -> Correlithm:
        """The point for (x, y) (:attr:`missing` for ``None`` or a NaN coordinate)."""
        if value is None:
            return self._missing
        x, y = value
        if math.isnan(x) or math.isnan(y):
            return self._missing
        return self._plane.at_xy(
            (x - self._min_x) / (self._max_x - self._min_x),
            (y - self._min_y) / (self._max_y - self._min_y),
        )
