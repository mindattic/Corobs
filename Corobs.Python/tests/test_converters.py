import math

import pytest

from corobs import (CardinalConverter, ContinuousConverter, Correlithm, NCube, OrdinalConverter,
                    PlanarConverter, SeededPrng)

N = 128


def test_cardinal_values_are_fixed_tokens_at_standard_distance_from_each_other():
    c = CardinalConverter(SeededPrng(1), N)
    again = CardinalConverter(SeededPrng(1), N)
    first = c.convert("Underclan")
    assert c.convert("Underclan") is first, "a value is one token, cached"
    assert again.convert("Underclan") == first, "same seed, same token, whatever was seen first"
    mu = NCube.standard_distance(N)
    assert c.convert("Underclan").distance_to(c.convert("Arcturus")) / mu == pytest.approx(1, abs=0.2)
    assert c.convert(None) == Correlithm.midpoint(N)


def test_ordinal_neighbours_are_closer_than_extremes_and_unknowns_throw():
    tiers = ["street", "runner", "fixer", "corpo", "board"]
    c = OrdinalConverter(SeededPrng(2), N, tiers)
    assert c.convert("street").distance_to(c.convert("runner")) < c.convert("street").distance_to(c.convert("board"))
    with pytest.raises(ValueError):
        c.convert("god")
    assert c.convert(None) == c.missing
    assert c.count == 5
    with pytest.raises(ValueError):
        OrdinalConverter(SeededPrng(2), N, [])


def test_continuous_values_interpolate_and_can_wrap():
    years = ContinuousConverter(SeededPrng(3), N, 2200, 2300)
    assert years.convert(2230).distance_to(years.convert(2231)) < years.convert(2230).distance_to(years.convert(2290))
    assert years.convert(None) == years.missing
    assert years.convert(math.nan) == years.missing

    hours = ContinuousConverter(SeededPrng(4), N, 0, 24, wraps=True)
    assert hours.convert(23.5).distance_to(hours.convert(0.5)) < hours.convert(23.5).distance_to(hours.convert(12))
    with pytest.raises(ValueError):
        ContinuousConverter(SeededPrng(4), N, 5, 5)


def test_planar_positions_are_near_when_the_map_says_so():
    m = PlanarConverter(SeededPrng(5), N, -10, 10, -10, 10)
    here = m.convert((0.0, 0.0))
    assert here.distance_to(m.convert((0.5, 0.5))) < here.distance_to(m.convert((8.0, -7.0)))
    assert m.convert(None) == m.missing
    with pytest.raises(ValueError):
        PlanarConverter(SeededPrng(5), N, 0, 0, 0, 1)
