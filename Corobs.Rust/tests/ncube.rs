//! Table II-1 and Ch. III, checked against the cube itself.

use corobs::geometry::ncube;
use corobs::{Correlithm, SeededPrng};

fn mean(xs: &[f64]) -> f64 {
    xs.iter().sum::<f64>() / xs.len() as f64
}

fn random_points_sit_at_standard_distance_with_the_books_deviation(n: usize) {
    let mut prng = SeededPrng::new(2004);
    let distances: Vec<f64> = (0..3000)
        .map(|_| {
            let a = Correlithm::random(&mut prng, n).unwrap();
            let b = Correlithm::random(&mut prng, n).unwrap();
            a.distance_to(&b)
        })
        .collect();
    let m = mean(&distances);
    let sd = (distances.iter().map(|d| (d - m) * (d - m)).sum::<f64>()
        / (distances.len() - 1) as f64)
        .sqrt();
    assert!(
        (m - ncube::standard_distance(n).unwrap()).abs() <= 0.03,
        "μ = √(N/6)"
    );
    assert!(
        (sd - ncube::STANDARD_DEVIATION).abs() <= 0.025,
        "σ = √(7/120), independent of N"
    );
}

#[test]
fn random_points_sit_at_standard_distance_with_the_books_deviation_64() {
    random_points_sit_at_standard_distance_with_the_books_deviation(64);
}

#[test]
fn random_points_sit_at_standard_distance_with_the_books_deviation_100() {
    random_points_sit_at_standard_distance_with_the_books_deviation(100);
}

fn midpoint_and_corner_distances_match_the_table(n: usize) {
    let mut prng = SeededPrng::new(7);
    let mid = Correlithm::midpoint(n).unwrap();
    let corner = Correlithm::new(&vec![0.0; n]).unwrap();
    let mut to_mid = Vec::new();
    let mut to_corner = Vec::new();
    for _ in 0..2000 {
        let p = Correlithm::random(&mut prng, n).unwrap();
        to_mid.push(p.distance_to(&mid));
        to_corner.push(p.distance_to(&corner));
    }
    assert!(
        (mean(&to_mid) - ncube::standard_radius(n).unwrap()).abs() <= 0.02,
        "standard radius √(N/12)"
    );
    assert!(
        (mean(&to_corner) - ncube::standard_diameter(n).unwrap()).abs() <= 0.03,
        "standard diameter √(N/3)"
    );
    assert!((ncube::half_diagonal(n).unwrap() - mid.distance_to(&corner)).abs() <= 1e-12);
}

#[test]
fn midpoint_and_corner_distances_match_the_table_64() {
    midpoint_and_corner_distances_match_the_table(64);
}

#[test]
fn midpoint_and_corner_distances_match_the_table_100() {
    midpoint_and_corner_distances_match_the_table(100);
}

#[test]
fn bit_content_follows_equation_iii_h() {
    let n = 100;
    let mu = ncube::standard_distance(n).unwrap();
    assert_eq!(ncube::bit_content(n, mu).unwrap(), 0.0);
    assert_eq!(
        ncube::bit_content(n, mu + 1.0).unwrap(),
        0.0,
        "beyond μ carries nothing"
    );
    // 24.75·(μ−d)² is the book's rounded form of ((μ−d)/σ)²/ln 2.
    assert!((ncube::bit_content(n, mu - 1.0).unwrap() - 24.75).abs() <= 0.1);
    // Rule of thumb: a little over four bits per dimension at d = 0.
    assert!((ncube::bit_content(n, 0.0).unwrap() / n as f64 - 4.12).abs() <= 0.02);
    assert!((ncube::distance_for_bits(n, 24.75).unwrap() - (mu - 1.0)).abs() <= 0.005);
}

#[test]
fn probability_of_proximity_is_two_to_the_minus_bits() {
    let n = 100;
    let mu = ncube::standard_distance(n).unwrap();
    assert_eq!(ncube::probability_of_proximity(n, mu).unwrap(), 1.0);
    // Eq. III-J: 10^(−7.45(μ−d)²); at μ−d = 0.5 → 10^−1.86.
    assert!(
        (ncube::probability_of_proximity(n, mu - 0.5)
            .unwrap()
            .log10()
            + 1.86)
            .abs()
            <= 0.02
    );
}

#[test]
fn point_capacity_follows_equation_iii_q() {
    // Book: N=96, d=1.0 → about 10^33 points before a pair falls within 1.0 of each other.
    assert!((ncube::point_capacity(96, 1.0).unwrap().log10() - 33.3).abs() <= 0.3);
    assert_eq!(
        ncube::point_capacity(96, ncube::standard_distance(96).unwrap()).unwrap(),
        1.0
    );
}

#[test]
fn deviations_and_distances_round_trip() {
    let n = 64;
    let d = ncube::distance_at_deviations(n, 6.0).unwrap();
    assert!((ncube::deviations_below(n, d).unwrap() - 6.0).abs() <= 1e-9);
    assert!(
        (ncube::bit_content(n, d).unwrap() - 36.0 / 2f64.ln()).abs() <= 1e-9,
        "6σ ≈ 52 bits"
    );
}
