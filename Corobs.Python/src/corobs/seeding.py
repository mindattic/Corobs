"""Deterministic randomness: xoshiro256** seeded through SplitMix64."""

from __future__ import annotations

__all__ = ["SeededPrng"]

_MASK = 0xFFFFFFFFFFFFFFFF
_FNV_OFFSET = 14695981039346656037
_FNV_PRIME = 1099511628211
_INV_2_53 = 1.0 / (1 << 53)


def _to_signed(x: int) -> int:
    return x - (1 << 64) if x >= 1 << 63 else x


def _rotl(x: int, k: int) -> int:
    return ((x << k) | (x >> (64 - k))) & _MASK


class SeededPrng:
    """A deterministic pseudo-random stream (xoshiro256** seeded through SplitMix64).

    The same seed yields the same values on every machine and in every language port of Corobs.
    Everything stochastic in COROBS draws from one of these, so a space can be rebuilt bit-for-bit
    from its seed.
    """

    __slots__ = ("_seed", "_s0", "_s1", "_s2", "_s3")

    def __init__(self, seed: int) -> None:
        if not -(1 << 63) <= seed < (1 << 63):
            raise ValueError("seed must fit a signed 64-bit integer")
        self._seed = int(seed)
        x = seed & _MASK
        state = []
        for _ in range(4):
            x = (x + 0x9E3779B97F4A7C15) & _MASK
            z = x
            z = ((z ^ (z >> 30)) * 0xBF58476D1CE4E5B9) & _MASK
            z = ((z ^ (z >> 27)) * 0x94D049BB133111EB) & _MASK
            state.append(z ^ (z >> 31))
        self._s0, self._s1, self._s2, self._s3 = state

    @property
    def seed(self) -> int:
        """The root seed this stream (or derive chain) was built from, as a signed 64-bit integer."""
        return self._seed

    def derive(self, label: str) -> "SeededPrng":
        """A child stream named by ``label``: the same parent seed and label always give the same
        child, independent of how many values the parent has produced."""
        h = _FNV_OFFSET
        s = self._seed & _MASK
        for i in range(8):
            h = ((h ^ ((s >> (8 * i)) & 0xFF)) * _FNV_PRIME) & _MASK
        for b in label.encode("utf-8"):
            h = ((h ^ b) * _FNV_PRIME) & _MASK
        return SeededPrng(_to_signed(h))

    def next_uint64(self) -> int:
        """The next raw 64-bit word of the xoshiro256** stream, in [0, 2**64)."""
        s0, s1, s2, s3 = self._s0, self._s1, self._s2, self._s3
        result = (_rotl((s1 * 5) & _MASK, 7) * 9) & _MASK
        t = (s1 << 17) & _MASK
        s2 ^= s0
        s3 ^= s1
        s1 ^= s2
        s0 ^= s3
        s2 ^= t
        s3 = _rotl(s3, 45)
        self._s0, self._s1, self._s2, self._s3 = s0, s1, s2, s3
        return result

    def next_double(self) -> float:
        """Uniform on [0, 1)."""
        return (self.next_uint64() >> 11) * _INV_2_53

    def next_int(self, max_exclusive: int) -> int:
        """Uniform integer on [0, ``max_exclusive``)."""
        if max_exclusive <= 0:
            raise ValueError("max_exclusive must be positive")
        return int(self.next_double() * max_exclusive)
