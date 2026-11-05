//! COR-T5 is a decision, not a proven error (docs/BUGS.md): this test pins the chosen behaviour.

use corobs::{ContinuousConverter, Converter, SeededPrng};

fn decision_a_wrapping_converter_maps_infinity_to_missing(value: f64) {
    let mut hours = ContinuousConverter::new(&mut SeededPrng::new(1), 32, 0.0, 24.0, true).unwrap();
    assert_eq!(&hours.convert(Some(&value)).unwrap(), hours.missing());
}

#[test]
fn decision_a_wrapping_converter_maps_positive_infinity_to_missing() {
    decision_a_wrapping_converter_maps_infinity_to_missing(f64::INFINITY);
}

#[test]
fn decision_a_wrapping_converter_maps_negative_infinity_to_missing() {
    decision_a_wrapping_converter_maps_infinity_to_missing(f64::NEG_INFINITY);
}
