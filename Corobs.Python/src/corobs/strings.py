"""String COs (Ch. VII): lines, rings and planes embedded in the N-cube."""

from __future__ import annotations

import math

from .geometry import Correlithm
from .seeding import SeededPrng

__all__ = ["StringCo"]

_LINE, _RING, _PLANE = "line", "ring", "plane"


class StringCo:
    """A string CO (Ch. VII): a lower-dimensional geometry embedded in the N-cube so that distance
    along it becomes distance in the cube, rising from zero to standard distance, while every
    position stays at standard distance from unrelated points.

    Each dimension carries two random values and switches between them at its own random breakpoint
    ("distribute the anomalies randomly"); no interpolation, so no position takes a shortcut.
    """

    __slots__ = ("_kind", "_a", "_b", "_o", "_dx", "_dy")

    def __init__(self, *_: object) -> None:
        raise TypeError("Use StringCo.line, StringCo.ring or StringCo.plane.")

    @classmethod
    def _make(cls, kind, a, b, o, dx=None, dy=None) -> "StringCo":
        s = cls.__new__(cls)
        s._kind, s._a, s._b, s._o, s._dx, s._dy = kind, a, b, o, dx, dy
        return s

    @property
    def dimensions(self) -> int:
        """N: the dimensionality of the cube this geometry is embedded in."""
        return len(self._a)

    @staticmethod
    def line(prng: SeededPrng, dimensions: int) -> "StringCo":
        """A segment parameterised by t in [0, 1]; distance between t and t' ~ mu * sqrt|t - t'|."""
        a, b = StringCo._values(prng, dimensions)
        o = [prng.next_double() for _ in range(dimensions)]
        return StringCo._make(_LINE, a, b, o)

    @staticmethod
    def ring(prng: SeededPrng, dimensions: int) -> "StringCo":
        """A closed ring parameterised by t in [0, 1) with 0 = 1 (hours, headings, seasons)."""
        a, b = StringCo._values(prng, dimensions)
        o = [prng.next_double() for _ in range(dimensions)]
        return StringCo._make(_RING, a, b, o)

    @staticmethod
    def plane(prng: SeededPrng, dimensions: int) -> "StringCo":
        """A unit square parameterised by (x, y) in [0, 1]^2; each dimension watches a random
        direction, the symmetric cone of Fig. VII-10."""
        a, b = StringCo._values(prng, dimensions)
        o, dx, dy = [], [], []
        for _ in range(dimensions):
            theta = prng.next_double() * 2 * math.pi
            cx, cy = math.cos(theta), math.sin(theta)
            dx.append(cx)
            dy.append(cy)
            lo = min(0.0, cx) + min(0.0, cy)
            hi = max(0.0, cx) + max(0.0, cy)
            o.append(lo + prng.next_double() * (hi - lo))
        return StringCo._make(_PLANE, a, b, o, dx, dy)

    def at(self, t: float) -> Correlithm:
        """The point at t on a line (clamped to [0, 1]) or a ring (taken mod 1)."""
        if self._kind == _PLANE:
            raise TypeError("A planar string CO takes two coordinates.")
        if math.isnan(t):
            raise ValueError("t must not be NaN")
        a, b, o = self._a, self._b, self._o
        if self._kind == _LINE:
            t = _clamp01(t)
            return Correlithm._owned([a[i] if t < o[i] else b[i] for i in range(len(a))])
        if math.isinf(t):
            raise ValueError("A ring has no position at infinity.")
        c = []
        for i in range(len(a)):
            phase = t - o[i]
            phase -= math.floor(phase)
            c.append(a[i] if phase < 0.5 else b[i])
        return Correlithm._owned(c)

    def at_xy(self, x: float, y: float) -> Correlithm:
        """The point at (x, y) on a plane, each clamped to [0, 1]."""
        if self._kind != _PLANE:
            raise TypeError("Only a planar string CO takes two coordinates.")
        if math.isnan(x) or math.isnan(y):
            raise ValueError("x and y must not be NaN")
        x, y = _clamp01(x), _clamp01(y)
        a, b, o, dx, dy = self._a, self._b, self._o, self._dx, self._dy
        c = []
        for i in range(len(a)):
            p = x * dx[i] + y * dy[i]
            c.append(a[i] if p < o[i] else b[i])
        return Correlithm._owned(c)

    def at_index(self, index: int, count: int) -> Correlithm:
        """The ``index``-th of ``count`` evenly spaced positions: an ordinal set (Fig. VII-8)."""
        if count <= 0:
            raise ValueError("count must be positive")
        if index < 0 or index >= count:
            raise ValueError("index out of range")
        if self._kind == _RING:
            return self.at(index / count)
        return self.at(0.0 if count == 1 else index / (count - 1))

    @staticmethod
    def _values(prng: SeededPrng, dimensions: int) -> tuple[list[float], list[float]]:
        if dimensions <= 0:
            raise ValueError("dimensions must be positive")
        a, b = [], []
        for _ in range(dimensions):
            a.append(prng.next_double())
            b.append(prng.next_double())
        return a, b


def _clamp01(v: float) -> float:
    if v < 0:
        return 0.0
    if v > 1:
        return 1.0
    return v
