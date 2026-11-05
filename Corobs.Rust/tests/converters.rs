use corobs::geometry::ncube;
use corobs::{
    CardinalConverter, ContinuousConverter, Converter, CorobsError, Correlithm, OrdinalConverter,
    PlanarConverter, SeededPrng,
};

const N: usize = 128;

#[test]
fn cardinal_values_are_fixed_tokens_at_standard_distance_from_each_other() {
    let mut c = CardinalConverter::<str>::new(&SeededPrng::new(1), N).unwrap();
    let mut again = CardinalConverter::<str>::new(&SeededPrng::new(1), N).unwrap();
    again.convert(Some("someone else first")).unwrap();
    let first = c.convert(Some("Underclan")).unwrap();
    assert_eq!(
        c.convert(Some("Underclan")).unwrap(),
        first,
        "a value is one token, cached"
    );
    assert_eq!(
        again.convert(Some("Underclan")).unwrap(),
        first,
        "same seed, same token, whatever was seen first"
    );
    let mu = ncube::standard_distance(N).unwrap();
    let d = c
        .convert(Some("Underclan"))
        .unwrap()
        .distance_to(&c.convert(Some("Arcturus")).unwrap());
    assert!((d / mu - 1.0).abs() <= 0.2);
    assert_eq!(c.convert(None).unwrap(), Correlithm::midpoint(N).unwrap());
}

#[test]
fn ordinal_neighbours_are_closer_than_extremes_and_unknowns_throw() {
    let tiers = ["street", "runner", "fixer", "corpo", "board"];
    let mut c = OrdinalConverter::new(&mut SeededPrng::new(2), N, &tiers).unwrap();
    let street = c.convert(Some(&"street")).unwrap();
    let runner = c.convert(Some(&"runner")).unwrap();
    let board = c.convert(Some(&"board")).unwrap();
    assert!(street.distance_to(&runner) < street.distance_to(&board));
    assert!(matches!(
        c.convert(Some(&"god")),
        Err(CorobsError::Argument(_))
    ));
    assert_eq!(&c.convert(None).unwrap(), c.missing());
    assert_eq!(c.count(), 5);
}

#[test]
fn continuous_values_interpolate_and_can_wrap() {
    let mut years =
        ContinuousConverter::new(&mut SeededPrng::new(3), N, 2200.0, 2300.0, false).unwrap();
    let y2230 = years.convert(Some(&2230.0)).unwrap();
    assert!(
        y2230.distance_to(&years.convert(Some(&2231.0)).unwrap())
            < y2230.distance_to(&years.convert(Some(&2290.0)).unwrap())
    );
    assert_eq!(&years.convert(None).unwrap(), years.missing());
    assert_eq!(&years.convert(Some(&f64::NAN)).unwrap(), years.missing());

    let mut hours = ContinuousConverter::new(&mut SeededPrng::new(4), N, 0.0, 24.0, true).unwrap();
    let late = hours.convert(Some(&23.5)).unwrap();
    assert!(
        late.distance_to(&hours.convert(Some(&0.5)).unwrap())
            < late.distance_to(&hours.convert(Some(&12.0)).unwrap())
    );
}

#[test]
fn planar_positions_are_near_when_the_map_says_so() {
    let mut map =
        PlanarConverter::new(&mut SeededPrng::new(5), N, -10.0, 10.0, -10.0, 10.0).unwrap();
    let here = map.convert(Some(&(0.0, 0.0))).unwrap();
    let close = map.convert(Some(&(0.5, 0.5))).unwrap();
    let far = map.convert(Some(&(8.0, -7.0))).unwrap();
    assert!(here.distance_to(&close) < here.distance_to(&far));
    assert_eq!(&map.convert(None).unwrap(), map.missing());
}
