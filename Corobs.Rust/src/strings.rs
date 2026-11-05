//! String COs (Ch. VII): lines, rings and planes embedded in the N-cube.

use std::f64::consts::PI;

use crate::error::{out_of_range, CorobsError, Result};
use crate::geometry::Correlithm;
use crate::seeding::SeededPrng;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum Kind {
    Line,
    Ring,
    Plane,
}

/// A string CO (Ch. VII): a lower-dimensional geometry (a line, a ring, a plane) embedded in the
/// N-cube so that distance along the geometry is reflected as distance in the cube, rising from zero
/// to standard distance as positions move apart, while every position stays at standard distance
/// from any unrelated random point.
///
/// Construction follows the book's advice to "distribute the anomalies randomly": each dimension
/// carries two random values and switches between them at its own random breakpoint along the
/// geometry. Two positions then differ in exactly the dimensions whose breakpoint lies between them,
/// so the expected squared distance is μ² times the fraction of such dimensions: √|Δt|·μ on a line,
/// √(2Δ)·μ around a ring (Δ ≤ ½), and isotropic in the plane. No interpolation is involved, so no
/// position "takes a shortcut" toward third points.
#[derive(Clone, Debug)]
pub struct StringCo {
    kind: Kind,
    a: Vec<f64>,
    b: Vec<f64>,
    o: Vec<f64>,
    dx: Vec<f64>,
    dy: Vec<f64>,
}

impl StringCo {
    /// A line segment parameterised by t ∈ [0, 1]. Distance between t and t′ ≈ μ·√|t − t′|.
    pub fn line(prng: &mut SeededPrng, dimensions: usize) -> Result<Self> {
        Self::one_dimensional(Kind::Line, prng, dimensions)
    }

    /// A closed ring parameterised by t ∈ [0, 1) with 0 ≡ 1, for hours, headings, seasons.
    /// Distance between t and t′ ≈ μ·√(2Δ) where Δ is the circular gap (≤ ½).
    pub fn ring(prng: &mut SeededPrng, dimensions: usize) -> Result<Self> {
        Self::one_dimensional(Kind::Ring, prng, dimensions)
    }

    /// A unit square parameterised by (x, y) ∈ [0, 1]². Each dimension watches a random direction,
    /// so distance grows with planar separation in every direction alike: the symmetric "cone" of
    /// Fig. VII-10, without the troughs of concatenated 1-D strings (Fig. VII-11).
    pub fn plane(prng: &mut SeededPrng, dimensions: usize) -> Result<Self> {
        let (a, b) = values(prng, dimensions)?;
        let mut o = Vec::with_capacity(dimensions);
        let mut dx = Vec::with_capacity(dimensions);
        let mut dy = Vec::with_capacity(dimensions);
        for _ in 0..dimensions {
            let theta = prng.next_double() * 2.0 * PI;
            let (x, y) = (theta.cos(), theta.sin());
            let min = 0f64.min(x) + 0f64.min(y);
            let max = 0f64.max(x) + 0f64.max(y);
            o.push(min + prng.next_double() * (max - min));
            dx.push(x);
            dy.push(y);
        }
        Ok(Self {
            kind: Kind::Plane,
            a,
            b,
            o,
            dx,
            dy,
        })
    }

    fn one_dimensional(kind: Kind, prng: &mut SeededPrng, dimensions: usize) -> Result<Self> {
        let (a, b) = values(prng, dimensions)?;
        let o = (0..dimensions).map(|_| prng.next_double()).collect();
        Ok(Self {
            kind,
            a,
            b,
            o,
            dx: Vec::new(),
            dy: Vec::new(),
        })
    }

    /// N: the dimensionality of the cube this geometry is embedded in.
    pub fn dimensions(&self) -> usize {
        self.a.len()
    }

    /// The point at position t on a line (clamped to [0, 1]) or a ring (taken mod 1). NaN has no
    /// position, and neither has ±∞ on a ring (COR-T4, docs/BUGS.md).
    pub fn at(&self, t: f64) -> Result<Correlithm> {
        if self.kind == Kind::Plane {
            return Err(CorobsError::InvalidOperation(
                "a planar string CO takes two coordinates".into(),
            ));
        }
        if t.is_nan() {
            return out_of_range("t must not be NaN");
        }
        let c = if self.kind == Kind::Line {
            let t = t.clamp(0.0, 1.0);
            self.pick(|i| t < self.o[i])
        } else {
            if t.is_infinite() {
                return out_of_range("t: a ring has no position at infinity");
            }
            self.pick(|i| {
                let mut phase = t - self.o[i];
                phase -= phase.floor();
                phase < 0.5
            })
        };
        Ok(Correlithm::from_vec(c))
    }

    /// The point at (x, y) on a plane, each clamped to [0, 1].
    pub fn at_xy(&self, x: f64, y: f64) -> Result<Correlithm> {
        if self.kind != Kind::Plane {
            return Err(CorobsError::InvalidOperation(
                "only a planar string CO takes two coordinates".into(),
            ));
        }
        if x.is_nan() || y.is_nan() {
            return out_of_range("x, y must not be NaN");
        }
        let (x, y) = (x.clamp(0.0, 1.0), y.clamp(0.0, 1.0));
        Ok(Correlithm::from_vec(
            self.pick(|i| x * self.dx[i] + y * self.dy[i] < self.o[i]),
        ))
    }

    /// The `index`-th of `count` evenly spaced positions: an ordinal set such as an alphabet, a
    /// rank or a tier (Fig. VII-8).
    pub fn at_index(&self, index: usize, count: usize) -> Result<Correlithm> {
        if count == 0 {
            return out_of_range("count must be positive");
        }
        if index >= count {
            return out_of_range("index must lie in [0, count)");
        }
        if self.kind == Kind::Ring {
            return self.at(index as f64 / count as f64);
        }
        self.at(if count == 1 {
            0.0
        } else {
            index as f64 / (count - 1) as f64
        })
    }

    fn pick(&self, first: impl Fn(usize) -> bool) -> Vec<f64> {
        (0..self.a.len())
            .map(|i| if first(i) { self.a[i] } else { self.b[i] })
            .collect()
    }
}

fn values(prng: &mut SeededPrng, dimensions: usize) -> Result<(Vec<f64>, Vec<f64>)> {
    if dimensions == 0 {
        return out_of_range("dimensions must be positive");
    }
    let mut a = Vec::with_capacity(dimensions);
    let mut b = Vec::with_capacity(dimensions);
    for _ in 0..dimensions {
        a.push(prng.next_double());
        b.push(prng.next_double());
    }
    Ok((a, b))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_wrong_arity_is_an_invalid_operation() {
        let line = StringCo::line(&mut SeededPrng::new(1), 8).unwrap();
        let plane = StringCo::plane(&mut SeededPrng::new(1), 8).unwrap();
        assert!(matches!(
            line.at_xy(0.1, 0.1),
            Err(CorobsError::InvalidOperation(_))
        ));
        assert!(matches!(
            plane.at(0.1),
            Err(CorobsError::InvalidOperation(_))
        ));
        assert!(line.at(f64::NAN).is_err());
        assert!(line.at_index(3, 3).is_err());
        assert!(line.at_index(0, 0).is_err());
        assert!(StringCo::ring(&mut SeededPrng::new(1), 0).is_err());
    }
}
