use std::cmp::Ordering;
use std::collections::HashMap;
use std::fmt;
use std::hash::Hash;

use crate::error::{argument, out_of_range, Result};
use crate::geometry::{ncube, Correlithm};
use crate::mining::Rule;

/// A ranked contradiction candidate: a thing that sits inside a rule's source pattern yet lies at
/// or near standard distance from the rule's target, the anomaly a cueing system hands to the
/// expert (Ch. X–XI). What to do about it is the caller's hand decision.
#[derive(Clone, Debug)]
pub struct Hit<'a, TId> {
    /// The thing that breaks the rule.
    pub id: TId,
    /// The rule it breaks.
    pub rule: &'a Rule<TId>,
    /// Its distance from the source pattern's centroid.
    pub source_distance: f64,
    /// Its distance from the target pattern's centroid.
    pub target_distance: f64,
    /// Bits of its source distance × the rule's support.
    pub bits: f64,
    /// 1 for the strongest hit.
    pub rank: usize,
}

impl<TId: fmt::Display> fmt::Display for Hit<'_, TId> {
    /// The hit's rank, id and bits against the rule it violates, for logs and reports.
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "#{} {}: {:.1} bits — {}",
            self.rank, self.id, self.bits, self.rule
        )
    }
}

/// For every rule, every member of its source whose point on the target ply lies no closer than
/// [`target_deviations`](Self::target_deviations) σ below standard distance from the target
/// centroid is a hit. Bits = (bits of the member's own distance to the source centroid) × rule
/// support, so a thing deep inside a strong source that misses the target outranks a marginal
/// member of a weak one. Deterministic.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Cue {
    target_deviations: f64,
}

impl Default for Cue {
    /// A pass/fail line 1σ below standard distance.
    fn default() -> Self {
        Self {
            target_deviations: 1.0,
        }
    }
}

impl Cue {
    /// A cueing instrument using `target_deviations` as the pass/fail line.
    pub fn new(target_deviations: f64) -> Result<Self> {
        if target_deviations < 0.0 {
            return out_of_range("target_deviations must not be negative");
        }
        Ok(Self { target_deviations })
    }

    /// How close to the target centroid, in σ below standard distance, a member must land to not
    /// count as a hit.
    pub fn target_deviations(&self) -> f64 {
        self.target_deviations
    }

    /// The hits against confirmed `rules`, given each ply's points by id (keyed by ply name),
    /// ordered by bits descending then id ascending and ranked from 1.
    pub fn find<'a, TId: Ord + Hash + Clone>(
        &self,
        rules: &'a [Rule<TId>],
        plies: &HashMap<String, HashMap<TId, Correlithm>>,
    ) -> Result<Vec<Hit<'a, TId>>> {
        let mut hits = Vec::new();
        for rule in rules {
            let Some(source_points) = plies.get(&rule.source_ply) else {
                return argument(format!("plies: no points for ply '{}'", rule.source_ply));
            };
            let Some(target_points) = plies.get(&rule.target_ply) else {
                return argument(format!("plies: no points for ply '{}'", rule.target_ply));
            };
            let n = rule.target.centroid().dimensions();
            let far_enough = ncube::distance_at_deviations(n, self.target_deviations)?;
            for id in rule.source.members() {
                let (Some(tp), Some(sp)) = (target_points.get(id), source_points.get(id)) else {
                    continue;
                };
                let target_distance = tp.try_distance_to(rule.target.centroid())?;
                if target_distance < far_enough {
                    continue;
                }
                let source_distance = sp.try_distance_to(rule.source.centroid())?;
                let bits = ncube::bit_content(sp.dimensions(), source_distance)? * rule.support;
                hits.push(Hit {
                    id: id.clone(),
                    rule,
                    source_distance,
                    target_distance,
                    bits,
                    rank: 0,
                });
            }
        }
        hits.sort_by(|a, b| {
            b.bits
                .partial_cmp(&a.bits)
                .unwrap_or(Ordering::Equal)
                .then_with(|| a.id.cmp(&b.id))
        });
        for (i, h) in hits.iter_mut().enumerate() {
            h.rank = i + 1;
        }
        Ok(hits)
    }
}
