use std::cmp::Ordering;
use std::fmt;
use std::hash::Hash;

use crate::error::{argument, out_of_range, Result};
use crate::mining::Pattern;

/// A rule `s.p >: t.q` (Ch. IV): things inside pattern [`source`](Self::source) on ply
/// [`source_ply`](Self::source_ply) are found inside pattern [`target`](Self::target) on ply
/// [`target_ply`](Self::target_ply) with the given [`support`](Self::support). These are the strings
/// that pull.
#[derive(Clone, Debug)]
pub struct Rule<TId> {
    /// The ply the source pattern lives on.
    pub source_ply: String,
    /// The pattern whose members the rule speaks about.
    pub source: Pattern<TId>,
    /// The ply the target pattern lives on.
    pub target_ply: String,
    /// Where the source's members are found.
    pub target: Pattern<TId>,
    /// The share of the source's members found in the target.
    pub support: f64,
    /// Support × the source pattern's bits.
    pub bits: f64,
}

impl<TId> fmt::Display for Rule<TId> {
    /// The rule's plies, pattern sizes, support and bits, for logs and reports.
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "{}.[{}] >: {}.[{}] support {:.0}%, {:.1} bits",
            self.source_ply,
            self.source.members().len(),
            self.target_ply,
            self.target.members().len(),
            self.support * 100.0,
            self.bits
        )
    }
}

/// Proposes rules between the patterns of two plies: for every source pattern, the target pattern
/// that holds the largest share of its members, kept when that share reaches
/// [`min_support`](Self::min_support). Bits = support × the source pattern's bits. Deterministic.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct RuleMiner {
    min_support: f64,
}

impl Default for RuleMiner {
    /// A minimum support of 0.8.
    fn default() -> Self {
        Self { min_support: 0.8 }
    }
}

impl RuleMiner {
    /// A miner that proposes rules whose support reaches `min_support`, in (0, 1].
    pub fn new(min_support: f64) -> Result<Self> {
        if min_support <= 0.0 || min_support > 1.0 {
            return out_of_range("min_support must lie in (0, 1]");
        }
        Ok(Self { min_support })
    }

    /// The smallest share of a source pattern's members that must land in the best target pattern
    /// for a rule to be proposed.
    pub fn min_support(&self) -> f64 {
        self.min_support
    }

    /// The rules from `source_ply`'s patterns (`source`) to `target_ply`'s (`target`) that reach
    /// the minimum support, ordered by bits descending (ties keep source order).
    pub fn mine<TId: Eq + Hash + Clone>(
        &self,
        source_ply: &str,
        source: &[Pattern<TId>],
        target_ply: &str,
        target: &[Pattern<TId>],
    ) -> Result<Vec<Rule<TId>>> {
        if source_ply == target_ply {
            return argument("target_ply: a rule relates two different plies");
        }
        let mut rules = Vec::new();
        for p in source {
            let mut best: Option<&Pattern<TId>> = None;
            let mut best_count = 0usize;
            for q in target {
                let count = p.members().iter().filter(|m| q.contains(m)).count();
                if count > best_count {
                    best = Some(q);
                    best_count = count;
                }
            }
            let Some(best) = best else { continue };
            let support = best_count as f64 / p.members().len() as f64;
            if support >= self.min_support {
                rules.push(Rule {
                    source_ply: source_ply.to_string(),
                    source: p.clone(),
                    target_ply: target_ply.to_string(),
                    target: best.clone(),
                    support,
                    bits: support * p.bits(),
                });
            }
        }
        rules.sort_by(|a, b| b.bits.partial_cmp(&a.bits).unwrap_or(Ordering::Equal));
        Ok(rules)
    }
}
