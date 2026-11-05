//! Pattern and rule mining, and cueing (Ch. IV, X–XI). Measurement, never judgment: every pattern,
//! rule and hit is a proposal; what it means, and whether it is true, is the caller's decision.

mod cue;
mod pattern;
mod pattern_miner;
mod rule_miner;

pub use cue::{Cue, Hit};
pub use pattern::{Pattern, PlyPoint};
pub use pattern_miner::PatternMiner;
pub use rule_miner::{Rule, RuleMiner};
