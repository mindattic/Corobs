//! # Corobs
//!
//! COROBS (COrrelation + algoRithm OBjectS) is a pure, deterministic implementation of
//! **Correlithm Object technology** as set out by Dr. P. Nick Lawrence in *Correlithm Object
//! Technology* (2004). Chapter, table and equation numbers in this crate refer to that book.
//!
//! This crate is a port of the C# reference implementation (`Corobs.Csharp`). Under the same seed
//! it reproduces the reference bit for bit; `tests/conformance.rs` checks it against
//! `conformance/vectors.json`.
//!
//! * [`geometry`]: the statistics of the unit N-cube ([`geometry::ncube`]) and the point CO
//!   ([`Correlithm`]).
//! * [`seeding`]: [`SeededPrng`], xoshiro256** under one seed, with labelled child streams.
//! * [`strings`]: [`StringCo`], line, ring and plane string COs (Ch. VII).
//! * [`converters`]: cardinal, ordinal, continuous and planar sensors (Ch. IX).
//! * [`mining`]: [`PatternMiner`], [`RuleMiner`] and [`Cue`] (Ch. IV, X–XI).
//! * [`bench`]: hold-out recall, reach and cascade yield over abstract ids.
//!
//! **Pure**: no I/O, database, network or LLM client, and no dependencies. **Deterministic**:
//! same seed, same inputs, same bits. **Measurement, never judgment**: the library ranks and cues;
//! confirming a pattern, accepting a rule and resolving a hit are the caller's decisions.
//!
//! ```
//! use corobs::{Correlithm, SeededPrng, geometry::ncube};
//!
//! let mut prng = SeededPrng::new(42);
//! let a = Correlithm::random(&mut prng, 100).unwrap();
//! let b = Correlithm::random(&mut prng, 100).unwrap();
//! let mu = ncube::standard_distance(100).unwrap();
//! assert!((a.distance_to(&b) - mu).abs() < 1.5);
//! ```

pub mod bench;
pub mod converters;
mod error;
pub mod geometry;
pub mod mining;
pub mod seeding;
pub mod strings;

pub use converters::{
    CardinalConverter, ContinuousConverter, Converter, OrdinalConverter, PlanarConverter,
};
pub use error::{CorobsError, Result};
pub use geometry::Correlithm;
pub use mining::{Cue, Hit, Pattern, PatternMiner, PlyPoint, Rule, RuleMiner};
pub use seeding::SeededPrng;
pub use strings::StringCo;
