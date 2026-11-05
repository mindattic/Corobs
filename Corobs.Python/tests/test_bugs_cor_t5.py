"""COR-T5 is a decision, not a proven error (docs/BUGS.md): pins the chosen behaviour."""

import math

import pytest

from corobs import ContinuousConverter, SeededPrng


@pytest.mark.parametrize("value", [math.inf, -math.inf])
def test_decision_a_wrapping_converter_maps_infinity_to_missing(value):
    hours = ContinuousConverter(SeededPrng(1), 32, 0, 24, wraps=True)
    assert hours.convert(value) == hours.missing
