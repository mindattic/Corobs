//! Converters move world data into CO space (a *sensor*, Ch. IX).

use std::collections::HashMap;
use std::fmt::Display;
use std::hash::Hash;

use crate::error::{argument, Result};
use crate::geometry::Correlithm;
use crate::seeding::SeededPrng;
use crate::strings::StringCo;

/// Moves world data into CO space (a *sensor*, Ch. IX). Every converter answers the same question
/// for a missing value: the cube's midpoint, which carries no bits.
pub trait Converter<T: ?Sized> {
    /// N: the dimensionality of the points this converter produces.
    fn dimensions(&self) -> usize;

    /// Where an absent value lands: [`Correlithm::midpoint`].
    fn missing(&self) -> &Correlithm;

    /// The point for a value, or [`missing`](Self::missing) for `None`.
    fn convert(&mut self, value: Option<&T>) -> Result<Correlithm>;
}

type KeyFn<T> = Box<dyn Fn(&T) -> String>;

/// `max > min`, false when either is NaN.
fn exceeds(max: f64, min: f64) -> bool {
    max.partial_cmp(&min) == Some(std::cmp::Ordering::Greater)
}

/// A cardinal set: values with no order (a faction, a species, a type). Each distinct value gets
/// its own random CO, derived from the seed and the value's key, so the mapping is the same on
/// every build regardless of the order values were first seen.
pub struct CardinalConverter<T: ?Sized> {
    root: SeededPrng,
    key: KeyFn<T>,
    cache: HashMap<String, Correlithm>,
    dimensions: usize,
    missing: Correlithm,
}

impl<T: ?Sized + Display> CardinalConverter<T> {
    /// A cardinal converter over `dimensions`-dimensional points, each value's random CO derived
    /// from `root` and the value's `Display` text.
    pub fn new(root: &SeededPrng, dimensions: usize) -> Result<Self> {
        Self::with_key(root, dimensions, |v: &T| v.to_string())
    }
}

impl<T: ?Sized> CardinalConverter<T> {
    /// A cardinal converter whose values are keyed by `key` instead of their `Display` text.
    pub fn with_key(
        root: &SeededPrng,
        dimensions: usize,
        key: impl Fn(&T) -> String + 'static,
    ) -> Result<Self> {
        Ok(Self {
            root: root.clone(),
            key: Box::new(key),
            cache: HashMap::new(),
            dimensions,
            missing: Correlithm::midpoint(dimensions)?,
        })
    }
}

impl<T: ?Sized> Converter<T> for CardinalConverter<T> {
    fn dimensions(&self) -> usize {
        self.dimensions
    }

    fn missing(&self) -> &Correlithm {
        &self.missing
    }

    /// The value's CO (created and cached on first use), or the midpoint for `None`.
    fn convert(&mut self, value: Option<&T>) -> Result<Correlithm> {
        let Some(value) = value else {
            return Ok(self.missing.clone());
        };
        let k = (self.key)(value);
        if let Some(co) = self.cache.get(&k) {
            return Ok(co.clone());
        }
        let co = Correlithm::random(&mut self.root.derive(&k), self.dimensions)?;
        self.cache.insert(k, co.clone());
        Ok(co)
    }
}

/// An ordinal set: values with an order but no scale (tiers, ranks, an alphabet). Evenly spaced
/// positions on a line string CO, so neighbours are near and the extremes are at standard distance
/// (Fig. VII-8). An unknown value is an error, not a guess.
#[derive(Clone, Debug)]
pub struct OrdinalConverter<T> {
    index: HashMap<T, usize>,
    line: StringCo,
    dimensions: usize,
    missing: Correlithm,
}

impl<T: Eq + Hash + Clone + Display> OrdinalConverter<T> {
    /// An ordinal converter whose `order[0]` is the first position, up to the last, evenly spaced
    /// along a fresh line string CO over `dimensions` dimensions.
    pub fn new(prng: &mut SeededPrng, dimensions: usize, order: &[T]) -> Result<Self> {
        if order.is_empty() {
            return argument("order: an ordinal set needs at least one value");
        }
        let mut index = HashMap::with_capacity(order.len());
        for (i, v) in order.iter().enumerate() {
            if index.insert(v.clone(), i).is_some() {
                return argument(format!("order: '{v}' appears twice"));
            }
        }
        let line = StringCo::line(prng, dimensions)?;
        Ok(Self {
            index,
            line,
            dimensions,
            missing: Correlithm::midpoint(dimensions)?,
        })
    }

    /// How many distinct values are in the order.
    pub fn count(&self) -> usize {
        self.index.len()
    }
}

impl<T: Eq + Hash + Clone + Display> Converter<T> for OrdinalConverter<T> {
    fn dimensions(&self) -> usize {
        self.dimensions
    }

    fn missing(&self) -> &Correlithm {
        &self.missing
    }

    /// The value's position on the line (the midpoint for `None`); an error for a value outside the
    /// ordered set, since there is no sensible place to guess it belongs.
    fn convert(&mut self, value: Option<&T>) -> Result<Correlithm> {
        let Some(value) = value else {
            return Ok(self.missing.clone());
        };
        match self.index.get(value) {
            Some(&i) => self.line.at_index(i, self.index.len()),
            None => argument(format!("value: '{value}' is not in this ordinal set")),
        }
    }
}

/// A continuous variable on [min, max] (an age, a date, a price) mapped onto a line string CO, or
/// onto a ring when the range wraps (hours of the day, compass bearings).
#[derive(Clone, Debug)]
pub struct ContinuousConverter {
    string: StringCo,
    min: f64,
    max: f64,
    wraps: bool,
    dimensions: usize,
    missing: Correlithm,
}

impl ContinuousConverter {
    /// A continuous converter over [`min`, `max`] on a fresh string CO of `dimensions` dimensions:
    /// a line, or a ring when `wraps` (the range's two ends are the same position).
    pub fn new(
        prng: &mut SeededPrng,
        dimensions: usize,
        min: f64,
        max: f64,
        wraps: bool,
    ) -> Result<Self> {
        if !exceeds(max, min) {
            return argument("max must exceed min");
        }
        let string = if wraps {
            StringCo::ring(prng, dimensions)?
        } else {
            StringCo::line(prng, dimensions)?
        };
        Ok(Self {
            string,
            min,
            max,
            wraps,
            dimensions,
            missing: Correlithm::midpoint(dimensions)?,
        })
    }
}

impl Converter<f64> for ContinuousConverter {
    fn dimensions(&self) -> usize {
        self.dimensions
    }

    fn missing(&self) -> &Correlithm {
        &self.missing
    }

    /// The value's point on the string; the midpoint for `None`, NaN, or an infinite value on a
    /// ring, which has no phase to land on (COR-T5, a decision; docs/BUGS.md).
    fn convert(&mut self, value: Option<&f64>) -> Result<Correlithm> {
        let v = match value {
            Some(&v) if !v.is_nan() => v,
            _ => return Ok(self.missing.clone()),
        };
        if self.wraps && v.is_infinite() {
            return Ok(self.missing.clone());
        }
        self.string.at((v - self.min) / (self.max - self.min))
    }
}

/// A point in a bounded plane (a map position) on a planar string CO (Fig. VII-10).
#[derive(Clone, Debug)]
pub struct PlanarConverter {
    plane: StringCo,
    min_x: f64,
    max_x: f64,
    min_y: f64,
    max_y: f64,
    dimensions: usize,
    missing: Correlithm,
}

impl PlanarConverter {
    /// A planar converter over the rectangle [`min_x`, `max_x`] × [`min_y`, `max_y`] on a fresh
    /// planar string CO of `dimensions` dimensions.
    pub fn new(
        prng: &mut SeededPrng,
        dimensions: usize,
        min_x: f64,
        max_x: f64,
        min_y: f64,
        max_y: f64,
    ) -> Result<Self> {
        if !exceeds(max_x, min_x) || !exceeds(max_y, min_y) {
            return argument("each axis needs max > min");
        }
        let plane = StringCo::plane(prng, dimensions)?;
        Ok(Self {
            plane,
            min_x,
            max_x,
            min_y,
            max_y,
            dimensions,
            missing: Correlithm::midpoint(dimensions)?,
        })
    }
}

impl Converter<(f64, f64)> for PlanarConverter {
    fn dimensions(&self) -> usize {
        self.dimensions
    }

    fn missing(&self) -> &Correlithm {
        &self.missing
    }

    /// The value's point on the plane; the midpoint for `None` or a NaN coordinate.
    fn convert(&mut self, value: Option<&(f64, f64)>) -> Result<Correlithm> {
        let Some(&(x, y)) = value else {
            return Ok(self.missing.clone());
        };
        if x.is_nan() || y.is_nan() {
            return Ok(self.missing.clone());
        }
        self.plane.at_xy(
            (x - self.min_x) / (self.max_x - self.min_x),
            (y - self.min_y) / (self.max_y - self.min_y),
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn bad_ranges_and_orders_are_refused() {
        let mut p = SeededPrng::new(1);
        assert!(ContinuousConverter::new(&mut p, 8, 1.0, 1.0, false).is_err());
        assert!(ContinuousConverter::new(&mut p, 8, 0.0, f64::NAN, false).is_err());
        assert!(PlanarConverter::new(&mut p, 8, 0.0, 1.0, 2.0, 1.0).is_err());
        assert!(OrdinalConverter::<&str>::new(&mut p, 8, &[]).is_err());
        assert!(OrdinalConverter::new(&mut p, 8, &["a", "a"]).is_err());
    }

    #[test]
    fn a_custom_key_decides_which_values_share_a_token() {
        let mut c =
            CardinalConverter::<str>::with_key(&SeededPrng::new(4), 16, |v| v.to_lowercase())
                .unwrap();
        assert_eq!(
            c.convert(Some("Red")).unwrap(),
            c.convert(Some("RED")).unwrap()
        );
        assert_ne!(
            c.convert(Some("red")).unwrap(),
            c.convert(Some("blue")).unwrap()
        );
    }
}
