import statistics

import pytest

from corobs import SeededPrng


def test_same_seed_same_stream():
    a, b = SeededPrng(42), SeededPrng(42)
    for _ in range(1000):
        assert a.next_uint64() == b.next_uint64()


def test_different_seeds_differ():
    a, b = SeededPrng(1), SeededPrng(2)
    assert [a.next_uint64() for _ in range(16)] != [b.next_uint64() for _ in range(16)]


def test_doubles_are_uniform_on_the_unit_interval():
    p = SeededPrng(99)
    xs = [p.next_double() for _ in range(20000)]
    assert all(0.0 <= x < 1.0 for x in xs)
    assert statistics.fmean(xs) == pytest.approx(0.5, abs=0.01)


def test_derive_is_deterministic_and_independent_of_consumption():
    a = SeededPrng(5)
    a.next_uint64()
    a.next_uint64()
    b = SeededPrng(5)
    assert a.derive("faction").seed == b.derive("faction").seed
    assert a.derive("faction").seed != b.derive("turf").seed
    assert a.derive("faction").seed != a.seed


def test_words_are_64_bit_and_seeds_signed():
    p = SeededPrng(-1)
    assert all(0 <= p.next_uint64() < 2**64 for _ in range(100))
    assert -(2**63) <= SeededPrng(0).derive("x").seed < 2**63
    with pytest.raises(ValueError):
        SeededPrng(2**63)
    with pytest.raises(ValueError):
        SeededPrng(1).next_int(0)
