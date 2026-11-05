"""Ch. VII: distance along the geometry becomes distance in the cube; strangers stay at mu."""

import math

import pytest

from corobs import Correlithm, NCube, SeededPrng, StringCo

N = 2048  # large so a single string's statistics are tight


def test_line_distance_grows_as_root_of_separation_and_reaches_mu():
    line = StringCo.line(SeededPrng(11), N)
    mu = NCube.standard_distance(N)
    origin = line.at(0)
    d1, d3, d6, d10 = (origin.distance_to(line.at(t)) for t in (0.1, 0.3, 0.6, 1.0))
    assert d1 < d3 < d6 < d10
    assert d1 / mu == pytest.approx(math.sqrt(0.1), abs=0.06), "~ mu sqrt|dt|"
    assert d10 / mu == pytest.approx(1, abs=0.06), "the far ends are at standard distance"
    assert origin.distance_to(origin) == 0


def test_ring_wraps():
    ring = StringCo.ring(SeededPrng(12), N)
    mu = NCube.standard_distance(N)
    origin = ring.at(0)
    assert origin.distance_to(ring.at(0.5)) / mu == pytest.approx(1, abs=0.06), "opposite side is mu"
    assert origin.distance_to(ring.at(0.98)) < origin.distance_to(ring.at(0.25)), "0.98 is next to 0"
    assert ring.at(0.3).distance_to(ring.at(1.3)) == 0, "t is taken mod 1"


def test_plane_is_isotropic():
    plane = StringCo.plane(SeededPrng(13), N)
    origin = plane.at_xy(0.5, 0.5)
    along_x = origin.distance_to(plane.at_xy(0.8, 0.5))
    along_y = origin.distance_to(plane.at_xy(0.5, 0.8))
    step = 0.3 / math.sqrt(2)
    diagonal = origin.distance_to(plane.at_xy(0.5 + step, 0.5 + step))
    assert along_x == pytest.approx(along_y, abs=along_y * 0.15)
    assert diagonal == pytest.approx(along_x, abs=along_x * 0.2)
    assert origin.distance_to(plane.at_xy(0.55, 0.5)) < along_x


def test_every_position_is_a_stranger_to_an_unrelated_point():
    prng = SeededPrng(14)
    line = StringCo.line(prng, N)
    stranger = Correlithm.random(prng, N)
    mu = NCube.standard_distance(N)
    for t in (0.0, 0.25, 0.5, 0.75, 1.0):
        assert line.at(t).distance_to(stranger) / mu == pytest.approx(1, abs=0.06)


def test_ordinal_positions_are_evenly_spaced():
    line = StringCo.line(SeededPrng(15), N)
    a, b, e, z = (line.at_index(i, 26) for i in (0, 1, 4, 25))
    assert a.distance_to(b) < a.distance_to(e) < a.distance_to(z)


def test_same_seed_same_string():
    assert StringCo.plane(SeededPrng(16), 64).at_xy(0.2, 0.7) == StringCo.plane(SeededPrng(16), 64).at_xy(0.2, 0.7)


def test_misuse_is_rejected():
    line = StringCo.line(SeededPrng(1), 8)
    plane = StringCo.plane(SeededPrng(1), 8)
    with pytest.raises(TypeError):
        plane.at(0.5)
    with pytest.raises(TypeError):
        line.at_xy(0.5, 0.5)
    with pytest.raises(ValueError):
        line.at(math.nan)
    with pytest.raises(ValueError):
        line.at_index(3, 3)
    with pytest.raises(ValueError):
        StringCo.line(SeededPrng(1), 0)
    with pytest.raises(TypeError):
        StringCo()
