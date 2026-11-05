"""Table II-1 and Ch. III, checked against the cube itself."""

import math
import statistics

import pytest

from corobs import Correlithm, NCube, SeededPrng


@pytest.mark.parametrize("n", [64, 100])
def test_random_points_sit_at_standard_distance_with_the_books_deviation(n):
    prng = SeededPrng(2004)
    distances = [Correlithm.random(prng, n).distance_to(Correlithm.random(prng, n)) for _ in range(3000)]
    assert statistics.fmean(distances) == pytest.approx(NCube.standard_distance(n), abs=0.03), "mu = sqrt(N/6)"
    assert statistics.stdev(distances) == pytest.approx(NCube.STANDARD_DEVIATION, abs=0.025), "sigma = sqrt(7/120)"


@pytest.mark.parametrize("n", [64, 100])
def test_midpoint_and_corner_distances_match_the_table(n):
    prng = SeededPrng(7)
    mid = Correlithm.midpoint(n)
    corner = Correlithm([0.0] * n)
    to_mid, to_corner = [], []
    for _ in range(2000):
        p = Correlithm.random(prng, n)
        to_mid.append(p.distance_to(mid))
        to_corner.append(p.distance_to(corner))
    assert statistics.fmean(to_mid) == pytest.approx(NCube.standard_radius(n), abs=0.02), "standard radius sqrt(N/12)"
    assert statistics.fmean(to_corner) == pytest.approx(NCube.standard_diameter(n), abs=0.03), "standard diameter sqrt(N/3)"
    assert NCube.half_diagonal(n) == pytest.approx(mid.distance_to(corner), abs=1e-12)


def test_bit_content_follows_equation_III_H():
    n = 100
    mu = NCube.standard_distance(n)
    assert NCube.bit_content(n, mu) == 0
    assert NCube.bit_content(n, mu + 1) == 0, "beyond mu carries nothing"
    # 24.75 (mu - d)^2 is the book's rounded form of ((mu - d)/sigma)^2 / ln 2.
    assert NCube.bit_content(n, mu - 1) == pytest.approx(24.75, abs=0.1)
    # Rule of thumb: a little over four bits per dimension at d = 0.
    assert NCube.bit_content(n, 0) / n == pytest.approx(4.12, abs=0.02)
    assert NCube.distance_for_bits(n, 24.75) == pytest.approx(mu - 1, abs=0.005)


def test_probability_of_proximity_is_two_to_the_minus_bits():
    n = 100
    mu = NCube.standard_distance(n)
    assert NCube.probability_of_proximity(n, mu) == 1
    # Eq. III-J: 10^(-7.45 (mu - d)^2); at mu - d = 0.5, 10^-1.86.
    assert math.log10(NCube.probability_of_proximity(n, mu - 0.5)) == pytest.approx(-1.86, abs=0.02)


def test_point_capacity_follows_equation_III_Q():
    # Book: N = 96, d = 1.0, about 10^33 points before a pair falls within 1.0 of each other.
    assert math.log10(NCube.point_capacity(96, 1.0)) == pytest.approx(33.3, abs=0.3)
    assert NCube.point_capacity(96, NCube.standard_distance(96)) == 1


def test_deviations_and_distances_round_trip():
    n = 64
    d = NCube.distance_at_deviations(n, 6)
    assert NCube.deviations_below(n, d) == pytest.approx(6, abs=1e-9)
    assert NCube.bit_content(n, d) == pytest.approx(36 / math.log(2), abs=1e-9), "6 sigma ~ 52 bits"


def test_dimensions_must_be_positive():
    with pytest.raises(ValueError):
        NCube.standard_distance(0)
    with pytest.raises(ValueError):
        NCube.distance_for_bits(20, -1)


def test_correlithm_validates_and_compares_exactly():
    with pytest.raises(ValueError):
        Correlithm([])
    with pytest.raises(ValueError):
        Correlithm([0.5, 1.5])
    with pytest.raises(ValueError):
        Correlithm([math.nan])
    a = Correlithm([0.1, 0.2])
    assert a == Correlithm([0.1, 0.2]) and hash(a) == hash(Correlithm([0.1, 0.2]))
    assert repr(a) == "CO[2]"
    with pytest.raises(ValueError):
        a.distance_to(Correlithm([0.1]))
    with pytest.raises(ValueError):
        a.interpolate(Correlithm([0.3, 0.4]), 1.5)
    with pytest.raises(ValueError):
        Correlithm.centroid([])
    assert Correlithm.superpose([a, Correlithm([0.3, 0.4])]).coordinates == pytest.approx((0.2, 0.3))
