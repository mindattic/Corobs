//! Ch. VII: distance along the geometry becomes distance in the cube; strangers stay at μ.

use corobs::geometry::ncube;
use corobs::{Correlithm, SeededPrng, StringCo};

const N: usize = 2048; // large so a single string's statistics are tight

fn near(actual: f64, expected: f64, within: f64) -> bool {
    (actual - expected).abs() <= within
}

#[test]
fn line_distance_grows_as_root_of_separation_and_reaches_mu() {
    let line = StringCo::line(&mut SeededPrng::new(11), N).unwrap();
    let mu = ncube::standard_distance(N).unwrap();
    let origin = line.at(0.0).unwrap();
    let d = |t: f64| origin.distance_to(&line.at(t).unwrap());
    let (d1, d3, d6, d10) = (d(0.1), d(0.3), d(0.6), d(1.0));
    assert!(d1 < d3 && d1 < d6);
    assert!(d3 < d6);
    assert!(d6 < d10);
    assert!(near(d1 / mu, 0.1f64.sqrt(), 0.06), "≈ μ·√|Δt|");
    assert!(
        near(d10 / mu, 1.0, 0.06),
        "the far ends are at standard distance"
    );
    assert_eq!(origin.distance_to(&origin), 0.0);
}

#[test]
fn ring_wraps() {
    let ring = StringCo::ring(&mut SeededPrng::new(12), N).unwrap();
    let mu = ncube::standard_distance(N).unwrap();
    let origin = ring.at(0.0).unwrap();
    let d = |t: f64| origin.distance_to(&ring.at(t).unwrap());
    assert!(near(d(0.5) / mu, 1.0, 0.06), "opposite side is μ");
    assert!(d(0.98) < d(0.25), "0.98 is next to 0");
    assert_eq!(
        ring.at(0.3).unwrap().distance_to(&ring.at(1.3).unwrap()),
        0.0,
        "t is taken mod 1"
    );
}

#[test]
fn plane_is_isotropic() {
    let plane = StringCo::plane(&mut SeededPrng::new(13), N).unwrap();
    let origin = plane.at_xy(0.5, 0.5).unwrap();
    let d = |x: f64, y: f64| origin.distance_to(&plane.at_xy(x, y).unwrap());
    let along_x = d(0.8, 0.5);
    let along_y = d(0.5, 0.8);
    let step = 0.3 / 2f64.sqrt();
    let diagonal = d(0.5 + step, 0.5 + step);
    assert!(near(along_x, along_y, along_y * 0.15));
    assert!(near(diagonal, along_x, along_x * 0.2));
    assert!(d(0.55, 0.5) < along_x);
}

#[test]
fn every_position_is_a_stranger_to_an_unrelated_point() {
    let mut prng = SeededPrng::new(14);
    let line = StringCo::line(&mut prng, N).unwrap();
    let stranger = Correlithm::random(&mut prng, N).unwrap();
    let mu = ncube::standard_distance(N).unwrap();
    for t in [0.0, 0.25, 0.5, 0.75, 1.0] {
        assert!(near(
            line.at(t).unwrap().distance_to(&stranger) / mu,
            1.0,
            0.06
        ));
    }
}

#[test]
fn ordinal_positions_are_evenly_spaced() {
    let line = StringCo::line(&mut SeededPrng::new(15), N).unwrap();
    let at = |i| line.at_index(i, 26).unwrap();
    let (a, b, e, z) = (at(0), at(1), at(4), at(25));
    assert!(a.distance_to(&b) < a.distance_to(&e));
    assert!(a.distance_to(&e) < a.distance_to(&z));
}

#[test]
fn same_seed_same_string() {
    let a = StringCo::plane(&mut SeededPrng::new(16), 64)
        .unwrap()
        .at_xy(0.2, 0.7)
        .unwrap();
    let b = StringCo::plane(&mut SeededPrng::new(16), 64)
        .unwrap()
        .at_xy(0.2, 0.7)
        .unwrap();
    assert_eq!(a, b);
}
