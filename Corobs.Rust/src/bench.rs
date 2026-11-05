//! Scores any way of relating things against any other on the same ground truth: the old way and
//! the COROBS way answer the same questions, and these are the questions. Everything here is
//! arithmetic over ids; the caller supplies the truth and the predictors.

use std::cmp::Ordering;
use std::collections::HashSet;
use std::fmt::Display;
use std::hash::Hash;

use crate::error::{out_of_range, Result};
use crate::seeding::SeededPrng;

/// How well a neighbour function recovers relationships that were hidden from it.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct RecallResult {
    /// Relationships hidden from the predictor.
    pub hidden: usize,
    /// Hidden relationships the predictor gave back.
    pub recovered: usize,
    /// Distinct pairs the predictor proposed.
    pub predicted: usize,
    /// Proposed pairs that are true anywhere in the full truth.
    pub predicted_true: usize,
}

impl RecallResult {
    /// Share of the hidden pairs that the predictor recovered.
    pub fn recall(&self) -> f64 {
        if self.hidden == 0 {
            0.0
        } else {
            self.recovered as f64 / self.hidden as f64
        }
    }

    /// Share of the predictor's own guesses that were actually true (anywhere in the full truth).
    pub fn precision(&self) -> f64 {
        if self.predicted == 0 {
            0.0
        } else {
            self.predicted_true as f64 / self.predicted as f64
        }
    }
}

/// How far a thing can reach through a relationship: mean reachable count per hop and how many
/// things reach nothing at all (dead records).
#[derive(Clone, Debug, PartialEq)]
pub struct ReachResult {
    /// Mean count of things reachable within 1, 2, … hops.
    pub mean_reachable_by_hop: Vec<f64>,
    /// Things that reach nothing.
    pub isolated: usize,
    /// Things measured.
    pub total: usize,
}

/// Hide `holdout_fraction` of the true pairs (deterministically, by seed), ask the predictor for
/// each hidden endpoint's neighbours, and count how many hidden pairs come back. Precision counts
/// predicted neighbours of those endpoints that are true pairs anywhere in the full truth.
///
/// A relationship is an unordered pair: a pair listed twice, or both ways round, is one
/// relationship to hide (COR-T4, docs/BUGS.md).
pub fn holdout_recall<TId, F, I>(
    true_pairs: &[(TId, TId)],
    holdout_fraction: f64,
    seed: i64,
    neighbours: F,
) -> Result<RecallResult>
where
    TId: Ord + Hash + Clone + Display,
    F: FnMut(&TId) -> I,
    I: IntoIterator<Item = TId>,
{
    holdout_recall_by(
        true_pairs,
        holdout_fraction,
        seed,
        neighbours,
        |id: &TId| id.clone(),
    )
}

/// [`holdout_recall`] where two ids are the same thing when their `key`s are equal: the caller's
/// equality, as C#'s `IEqualityComparer` gives it.
pub fn holdout_recall_by<TId, K, F, I, KF>(
    true_pairs: &[(TId, TId)],
    holdout_fraction: f64,
    seed: i64,
    mut neighbours: F,
    key: KF,
) -> Result<RecallResult>
where
    TId: Clone + Display,
    K: Ord + Hash + Clone,
    F: FnMut(&TId) -> I,
    I: IntoIterator<Item = TId>,
    KF: Fn(&TId) -> K,
{
    if holdout_fraction <= 0.0 || holdout_fraction >= 1.0 {
        return out_of_range("holdout_fraction must lie in (0, 1)");
    }
    let pair_key = |a: &TId, b: &TId| {
        let (ka, kb) = (key(a), key(b));
        if ka <= kb {
            (ka, kb)
        } else {
            (kb, ka)
        }
    };
    let truth: HashSet<(K, K)> = true_pairs.iter().map(|(a, b)| pair_key(a, b)).collect();

    let mut prng = SeededPrng::new(seed);
    let mut distinct: HashSet<(K, K)> = HashSet::new();
    let mut shuffled: Vec<(TId, TId)> = Vec::new();
    for (a, b) in true_pairs {
        if distinct.insert(pair_key(a, b)) {
            shuffled.push(canon(a, b));
        }
    }
    for i in (1..shuffled.len()).rev() {
        let j = prng.next_int((i + 1) as i32)? as usize;
        shuffled.swap(i, j);
    }
    let take =
        ((shuffled.len() as f64 * holdout_fraction).round_ties_even() as usize).min(shuffled.len());
    let hidden = &shuffled[..take];
    let mut hidden_set: HashSet<(K, K)> = hidden.iter().map(|(a, b)| pair_key(a, b)).collect();

    let mut endpoint_keys: HashSet<K> = HashSet::new();
    let mut endpoints: Vec<&TId> = Vec::new();
    for (a, b) in hidden {
        for e in [a, b] {
            if endpoint_keys.insert(key(e)) {
                endpoints.push(e);
            }
        }
    }

    let (mut recovered, mut predicted, mut predicted_true) = (0, 0, 0);
    let mut seen: HashSet<(K, K)> = HashSet::new();
    for e in endpoints {
        for nb in neighbours(e) {
            let pair = pair_key(e, &nb);
            if !seen.insert(pair.clone()) {
                continue;
            }
            predicted += 1;
            if truth.contains(&pair) {
                predicted_true += 1;
            }
            if hidden_set.remove(&pair) {
                recovered += 1;
            }
        }
    }
    Ok(RecallResult {
        hidden: hidden.len(),
        recovered,
        predicted,
        predicted_true,
    })
}

/// A pair in canonical order: the ids' text compared ordinally by UTF-16 code unit, as C#
/// `string.CompareOrdinal(a.ToString(), b.ToString())` does ("10" before "9").
fn canon<TId: Clone + Display>(a: &TId, b: &TId) -> (TId, TId) {
    let (sa, sb) = (a.to_string(), b.to_string());
    if sa.encode_utf16().cmp(sb.encode_utf16()) != Ordering::Greater {
        (a.clone(), b.clone())
    } else {
        (b.clone(), a.clone())
    }
}

/// Breadth-first reach from every id through `adjacency`, up to `max_hops`.
pub fn reach<TId, F, I>(ids: &[TId], mut adjacency: F, max_hops: usize) -> Result<ReachResult>
where
    TId: Eq + Hash + Clone,
    F: FnMut(&TId) -> I,
    I: IntoIterator<Item = TId>,
{
    if max_hops == 0 {
        return out_of_range("max_hops must be positive");
    }
    let mut sums = vec![0.0; max_hops];
    let mut isolated = 0;
    for start in ids {
        let mut visited: HashSet<TId> = HashSet::from([start.clone()]);
        let mut frontier = vec![start.clone()];
        let mut reached = 0usize;
        for hop in 0..max_hops {
            let mut next = Vec::new();
            for f in &frontier {
                for a in adjacency(f) {
                    if visited.insert(a.clone()) {
                        next.push(a);
                    }
                }
            }
            reached += next.len();
            sums[hop] += reached as f64;
            frontier = next;
            if frontier.is_empty() {
                for s in &mut sums[hop + 1..] {
                    *s += reached as f64;
                }
                break;
            }
        }
        if reached == 0 {
            isolated += 1;
        }
    }
    let means = sums
        .iter()
        .map(|s| {
            if ids.is_empty() {
                0.0
            } else {
                s / ids.len() as f64
            }
        })
        .collect();
    Ok(ReachResult {
        mean_reachable_by_hop: means,
        isolated,
        total: ids.len(),
    })
}

/// Hits that closed because something else was fixed, per direct fix. The old way scores zero by
/// construction; that is a fact to report, not to hide.
pub fn cascade_yield(closed_by_cascade: usize, direct_fixes: usize) -> f64 {
    if direct_fixes == 0 {
        0.0
    } else {
        closed_by_cascade as f64 / direct_fixes as f64
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn canon_orders_by_text_not_by_number() {
        assert_eq!(canon(&9, &10), (10, 9));
        assert_eq!(canon(&"b", &"a"), ("a", "b"));
    }

    #[test]
    fn bad_parameters_are_refused() {
        let pairs = [(1, 2)];
        assert!(holdout_recall(&pairs, 0.0, 1, |_| Vec::new()).is_err());
        assert!(holdout_recall(&pairs, 1.0, 1, |_| Vec::new()).is_err());
        assert!(reach(&[1], |_| Vec::new(), 0).is_err());
    }

    #[test]
    fn halves_round_to_even() {
        let pairs: Vec<(i32, i32)> = (0..5).map(|i| (2 * i, 2 * i + 1)).collect();
        assert_eq!(
            holdout_recall(&pairs, 0.5, 3, |_| Vec::new())
                .unwrap()
                .hidden,
            2
        );
    }
}
