use std::fmt;
use std::hash::{Hash, Hasher};
use std::ops::Index;

use crate::error::{argument, out_of_range, Result};
use crate::seeding::SeededPrng;

/// A correlithm object: one point in the real unit N-cube, every coordinate in [0, 1]. A CO is a
/// *soft token* (Ch. IV): it stands for its datum exactly at its coordinates and, to a degree
/// [`ncube::bit_content`](crate::geometry::ncube::bit_content) quantifies, at every point nearby.
/// Immutable.
///
/// Equality compares every coordinate exactly; it is not a proximity test. Use
/// [`distance_to`](Self::distance_to) for that.
#[derive(Clone, Debug)]
pub struct Correlithm {
    c: Vec<f64>,
}

impl Correlithm {
    /// A point at exactly these coordinates; each must lie in [0, 1].
    pub fn new(coordinates: &[f64]) -> Result<Self> {
        if coordinates.is_empty() {
            return argument("coordinates: a point needs at least one coordinate");
        }
        if coordinates
            .iter()
            .any(|v| v.is_nan() || *v < 0.0 || *v > 1.0)
        {
            return out_of_range("coordinates: every coordinate must lie in [0, 1]");
        }
        Ok(Self {
            c: coordinates.to_vec(),
        })
    }

    pub(crate) fn from_vec(c: Vec<f64>) -> Self {
        Self { c }
    }

    /// A point chosen uniformly at random from the whole cube: a fresh token, at standard distance
    /// from every other random token with overwhelming probability.
    pub fn random(prng: &mut SeededPrng, dimensions: usize) -> Result<Self> {
        check_dimensions(dimensions)?;
        Ok(Self::from_vec(
            (0..dimensions).map(|_| prng.next_double()).collect(),
        ))
    }

    /// The cube's centre, 0.5 in every dimension: where a missing value goes, because the midpoint
    /// is at standard radius from everything and carries no bits.
    pub fn midpoint(dimensions: usize) -> Result<Self> {
        check_dimensions(dimensions)?;
        Ok(Self::from_vec(vec![0.5; dimensions]))
    }

    /// N: the dimensionality of the cube this point lives in.
    pub fn dimensions(&self) -> usize {
        self.c.len()
    }

    /// All N coordinates, in order.
    pub fn coordinates(&self) -> &[f64] {
        &self.c
    }

    /// Euclidean distance squared to `other`, which must come from the same cube.
    pub fn try_squared_distance_to(&self, other: &Correlithm) -> Result<f64> {
        self.check_same(other)?;
        let mut s = 0.0;
        for (a, b) in self.c.iter().zip(&other.c) {
            let d = a - b;
            s += d * d;
        }
        Ok(s)
    }

    /// Euclidean distance squared to `other`.
    ///
    /// # Panics
    /// When the two points come from cubes of different dimensionality.
    pub fn squared_distance_to(&self, other: &Correlithm) -> f64 {
        self.try_squared_distance_to(other)
            .expect("points from different spaces have no distance")
    }

    /// Euclidean distance to `other`, which must come from the same cube. Compare against
    /// [`ncube::standard_distance`](crate::geometry::ncube::standard_distance) to read it as information.
    pub fn try_distance_to(&self, other: &Correlithm) -> Result<f64> {
        Ok(self.try_squared_distance_to(other)?.sqrt())
    }

    /// Euclidean distance to `other`.
    ///
    /// # Panics
    /// When the two points come from cubes of different dimensionality.
    pub fn distance_to(&self, other: &Correlithm) -> f64 {
        self.squared_distance_to(other).sqrt()
    }

    /// Linear interpolation by `fraction` from this point toward `other`. Note Ch. VII's warning:
    /// interpolated points "take a shortcut" and sit closer than standard distance to third points;
    /// use [`StringCo`](crate::StringCo) for sequences.
    pub fn interpolate(&self, other: &Correlithm, fraction: f64) -> Result<Correlithm> {
        self.check_same(other)?;
        if fraction < 0.0 || fraction > 1.0 {
            return out_of_range("fraction must lie in [0, 1]");
        }
        Ok(Self::from_vec(
            self.c
                .iter()
                .zip(&other.c)
                .map(|(a, b)| a + (b - a) * fraction)
                .collect(),
        ))
    }

    /// The coordinate-wise mean of a set of points, accumulated in order.
    pub fn centroid<'a>(points: impl IntoIterator<Item = &'a Correlithm>) -> Result<Correlithm> {
        let mut sum: Option<Vec<f64>> = None;
        let mut count = 0usize;
        for p in points {
            let s = sum.get_or_insert_with(|| vec![0.0; p.dimensions()]);
            if s.len() != p.dimensions() {
                return argument("points: all points must share one dimensionality");
            }
            for (acc, v) in s.iter_mut().zip(&p.c) {
                *acc += v;
            }
            count += 1;
        }
        let Some(mut sum) = sum else {
            return argument("points: a centroid needs at least one point");
        };
        for v in &mut sum {
            *v /= count as f64;
        }
        Ok(Self::from_vec(sum))
    }

    /// A point that superposes several: their centroid. Each component remains recoverable: the
    /// centroid of K random points lies closer to each than a random point would (Ch. VIII,
    /// Superposition).
    pub fn superpose<'a>(points: impl IntoIterator<Item = &'a Correlithm>) -> Result<Correlithm> {
        Self::centroid(points)
    }

    fn check_same(&self, other: &Correlithm) -> Result<()> {
        if other.c.len() != self.c.len() {
            return argument("other: points from different spaces have no distance");
        }
        Ok(())
    }
}

fn check_dimensions(dimensions: usize) -> Result<()> {
    if dimensions == 0 {
        return out_of_range("dimensions must be positive");
    }
    Ok(())
}

impl Index<usize> for Correlithm {
    type Output = f64;

    /// The coordinate on one dimension, in [0, 1].
    fn index(&self, dimension: usize) -> &f64 {
        &self.c[dimension]
    }
}

impl PartialEq for Correlithm {
    fn eq(&self, other: &Self) -> bool {
        self.c == other.c
    }
}

impl Eq for Correlithm {}

impl Hash for Correlithm {
    fn hash<H: Hasher>(&self, state: &mut H) {
        for v in &self.c {
            // +0.0 and -0.0 compare equal, so they must hash equal.
            (v + 0.0).to_bits().hash(state);
        }
    }
}

impl fmt::Display for Correlithm {
    /// Just the dimensionality; coordinates are not meant to be read as text.
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "CO[{}]", self.c.len())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn coordinates_must_lie_in_the_unit_interval() {
        assert!(Correlithm::new(&[]).is_err());
        assert!(Correlithm::new(&[0.5, 1.5]).is_err());
        assert!(Correlithm::new(&[f64::NAN]).is_err());
        assert!(Correlithm::new(&[0.0, 1.0]).is_ok());
    }

    #[test]
    fn different_spaces_have_no_distance() {
        let a = Correlithm::midpoint(3).unwrap();
        let b = Correlithm::midpoint(4).unwrap();
        assert!(a.try_distance_to(&b).is_err());
        assert!(a.interpolate(&b, 0.5).is_err());
        assert!(Correlithm::centroid([&a, &b]).is_err());
        assert!(Correlithm::centroid(std::iter::empty()).is_err());
    }

    #[test]
    fn equality_is_exact_and_hash_agrees_on_signed_zero() {
        use std::collections::HashSet;
        let a = Correlithm::new(&[0.0, 0.5]).unwrap();
        let b = Correlithm::from_vec(vec![-0.0, 0.5]);
        assert_eq!(a, b);
        assert!(HashSet::from([a]).contains(&b));
        assert_eq!(Correlithm::midpoint(7).unwrap().to_string(), "CO[7]");
    }
}
