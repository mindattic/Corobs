//! The statistics of the real unit N-cube (Lawrence, *Correlithm Object Technology*, Ch. II–III).
//!
//! Two points chosen at random are almost always [`standard_distance`] apart, with a standard
//! deviation that does not grow with N (Table II-1). Proximity far below that distance is therefore
//! information: [`bit_content`] says how much (Eq. III-H), [`probability_of_proximity`] how unlikely
//! by chance (Eq. III-J), [`point_capacity`] how many random points fit before two collide
//! (Eq. III-Q). Valid for N of about 20 and up; 50–128 is the working range.

use std::f64::consts::LN_2;

use crate::error::{out_of_range, Result};

/// σ of the distance between two random points: √(7/120) ≈ 0.2415, independent of N.
pub const STANDARD_DEVIATION: f64 = 0.241_522_945_769_823_97;

/// σ of the distance from the midpoint to a random point: √(1/60) ≈ 0.1291.
pub const RADIUS_DEVIATION: f64 = 0.129_099_444_873_580_55;

/// σ of the distance from a corner to a random point: √(1/15) ≈ 0.2582.
pub const DIAMETER_DEVIATION: f64 = 0.258_198_889_747_161_1;

fn check(dimensions: usize) -> Result<f64> {
    if dimensions == 0 {
        out_of_range(
            "dimensions: a space needs at least one dimension; the statistics hold from about 20",
        )
    } else {
        Ok(dimensions as f64)
    }
}

/// μ: expected distance between two random points, √(N/6).
pub fn standard_distance(dimensions: usize) -> Result<f64> {
    Ok((check(dimensions)? / 6.0).sqrt())
}

/// Expected distance from the midpoint to a random point, √(N/12).
pub fn standard_radius(dimensions: usize) -> Result<f64> {
    Ok((check(dimensions)? / 12.0).sqrt())
}

/// Expected distance from a corner to a random point, √(N/3).
pub fn standard_diameter(dimensions: usize) -> Result<f64> {
    Ok((check(dimensions)? / 3.0).sqrt())
}

/// Expected distance between two random corners, √(N/2).
pub fn corner_distance(dimensions: usize) -> Result<f64> {
    Ok((check(dimensions)? / 2.0).sqrt())
}

/// Midpoint to any corner, exactly √(N/4).
pub fn half_diagonal(dimensions: usize) -> Result<f64> {
    Ok((check(dimensions)? / 4.0).sqrt())
}

/// Opposite corners, exactly √N.
pub fn major_diagonal(dimensions: usize) -> Result<f64> {
    Ok(check(dimensions)?.sqrt())
}

/// How many standard deviations below μ a distance lies (negative when beyond μ).
pub fn deviations_below(dimensions: usize, distance: f64) -> Result<f64> {
    Ok((standard_distance(dimensions)? - distance) / STANDARD_DEVIATION)
}

/// The distance that lies `deviations` σ below μ.
pub fn distance_at_deviations(dimensions: usize, deviations: f64) -> Result<f64> {
    Ok(standard_distance(dimensions)? - deviations * STANDARD_DEVIATION)
}

/// Eq. III-H: bits of information in two points lying `distance` apart, ((μ − d)/σ)² / ln 2 ≈
/// 24.75·(μ − d)². Zero at or beyond standard distance. The book's rule of thumb, a little over
/// four bits per dimension at d = 0, falls out of this.
pub fn bit_content(dimensions: usize, distance: f64) -> Result<f64> {
    let x = deviations_below(dimensions, distance)?;
    Ok(if x <= 0.0 { 0.0 } else { x * x / LN_2 })
}

/// The distance at which proximity is worth `bits` bits.
pub fn distance_for_bits(dimensions: usize, bits: f64) -> Result<f64> {
    if bits < 0.0 {
        return out_of_range("bits must not be negative");
    }
    Ok(standard_distance(dimensions)? - STANDARD_DEVIATION * (bits * LN_2).sqrt())
}

/// Eq. III-J: the probability that two random points lie closer than `distance`,
/// 10^(−7.45(μ − d)²) = 2^(−bits). One at or beyond μ.
pub fn probability_of_proximity(dimensions: usize, distance: f64) -> Result<f64> {
    Ok(2f64.powf(-bit_content(dimensions, distance)?))
}

/// Eq. III-Q: how many random points can be placed before two are expected to lie closer than
/// `distance`, 10^(3.7(μ − d)²).
pub fn point_capacity(dimensions: usize, distance: f64) -> Result<f64> {
    let gap = standard_distance(dimensions)? - distance;
    Ok(if gap <= 0.0 {
        1.0
    } else {
        10f64.powf(3.7 * gap * gap)
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn zero_dimensions_is_refused() {
        assert!(standard_distance(0).is_err());
        assert!(bit_content(0, 1.0).is_err());
        assert!(distance_for_bits(20, -1.0).is_err());
    }

    #[test]
    fn the_constants_are_the_square_roots_in_table_ii_1() {
        assert!((STANDARD_DEVIATION - (7.0f64 / 120.0).sqrt()).abs() < 1e-15);
        assert!((RADIUS_DEVIATION - (1.0f64 / 60.0).sqrt()).abs() < 1e-15);
        assert!((DIAMETER_DEVIATION - (1.0f64 / 15.0).sqrt()).abs() < 1e-15);
    }
}
