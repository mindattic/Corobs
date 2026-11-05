use std::cmp::Ordering;
use std::collections::HashMap;
use std::hash::Hash;

use crate::error::{out_of_range, Result};
use crate::geometry::{ncube, Correlithm};
use crate::mining::{Pattern, PlyPoint};

/// Finds the clusters on one ply that are far tighter than chance: two points are linked when they
/// lie at least [`min_deviations`](Self::min_deviations) σ below standard distance (≈ 52 bits at
/// 6σ, Eq. III-H), linked points are joined by union-find, and a component with at least
/// [`min_members`](Self::min_members) members is a proposed [`Pattern`]. Deterministic: points are
/// processed in id order, and the output is ordered by bits then by first member.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct PatternMiner {
    min_deviations: f64,
    min_members: usize,
}

impl Default for PatternMiner {
    /// 6σ (≈ 52 bits) and at least 5 members.
    fn default() -> Self {
        Self {
            min_deviations: 6.0,
            min_members: 5,
        }
    }
}

impl PatternMiner {
    /// A miner that links points at `min_deviations` σ below standard distance and keeps clusters of
    /// at least `min_members`.
    pub fn new(min_deviations: f64, min_members: usize) -> Result<Self> {
        if min_deviations <= 0.0 {
            return out_of_range("min_deviations must be positive");
        }
        if min_members < 2 {
            return out_of_range("min_members must be at least 2");
        }
        Ok(Self {
            min_deviations,
            min_members,
        })
    }

    /// The linking threshold, in σ below standard distance.
    pub fn min_deviations(&self) -> f64 {
        self.min_deviations
    }

    /// The smallest cluster size kept as a pattern.
    pub fn min_members(&self) -> usize {
        self.min_members
    }

    /// The patterns found among `points` (all on the same ply), ordered by bits descending then by
    /// first member.
    pub fn mine<TId: Ord + Hash + Clone>(
        &self,
        points: &[PlyPoint<TId>],
    ) -> Result<Vec<Pattern<TId>>> {
        if points.len() < self.min_members {
            return Ok(Vec::new());
        }
        let n = points[0].point.dimensions();
        let mut sorted: Vec<&PlyPoint<TId>> = points.iter().collect();
        sorted.sort_by(|a, b| a.id.cmp(&b.id));
        let threshold = ncube::distance_at_deviations(n, self.min_deviations)?;
        // COR-T4 (docs/BUGS.md): distance is never negative, so a negative threshold links nothing.
        if threshold < 0.0 {
            return Ok(Vec::new());
        }
        let threshold_sq = threshold * threshold;

        let mut parent: Vec<usize> = (0..sorted.len()).collect();
        for (i, a) in sorted.iter().enumerate() {
            for (j, b) in sorted.iter().enumerate().skip(i + 1) {
                if a.point.try_squared_distance_to(&b.point)? <= threshold_sq {
                    union(&mut parent, i, j);
                }
            }
        }

        let mut groups: Vec<Vec<usize>> = Vec::new();
        let mut by_root: HashMap<usize, usize> = HashMap::new();
        for i in 0..sorted.len() {
            let root = find(&mut parent, i);
            let g = *by_root.entry(root).or_insert_with(|| {
                groups.push(Vec::new());
                groups.len() - 1
            });
            groups[g].push(i);
        }

        let mut result = Vec::new();
        for members in groups.iter().filter(|g| g.len() >= self.min_members) {
            let pts: Vec<&Correlithm> = members.iter().map(|&i| &sorted[i].point).collect();
            let centroid = Correlithm::centroid(pts.iter().copied())?;
            let mut radius = f64::NEG_INFINITY;
            for p in &pts {
                radius = radius.max(p.try_distance_to(&centroid)?);
            }
            let (mut sum, mut pairs) = (0.0, 0usize);
            for (a, pa) in pts.iter().enumerate() {
                for pb in &pts[a + 1..] {
                    sum += pa.try_distance_to(pb)?;
                    pairs += 1;
                }
            }
            let mean = sum / pairs as f64;
            let ids = members.iter().map(|&i| sorted[i].id.clone()).collect();
            result.push(Pattern::new(
                ids,
                centroid,
                radius,
                mean,
                ncube::bit_content(n, mean)?,
            ));
        }

        result.sort_by(|a, b| {
            b.bits()
                .partial_cmp(&a.bits())
                .unwrap_or(Ordering::Equal)
                .then_with(|| a.members()[0].cmp(&b.members()[0]))
        });
        Ok(result)
    }
}

fn find(parent: &mut [usize], mut i: usize) -> usize {
    while parent[i] != i {
        parent[i] = parent[parent[i]];
        i = parent[i];
    }
    i
}

fn union(parent: &mut [usize], a: usize, b: usize) {
    let (ra, rb) = (find(parent, a), find(parent, b));
    if ra == rb {
        return;
    }
    if ra < rb {
        parent[rb] = ra;
    } else {
        parent[ra] = rb;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn bad_parameters_are_refused() {
        assert!(PatternMiner::new(0.0, 5).is_err());
        assert!(PatternMiner::new(6.0, 1).is_err());
        assert_eq!(PatternMiner::default(), PatternMiner::new(6.0, 5).unwrap());
    }

    #[test]
    fn too_few_points_yield_nothing() {
        let p = PlyPoint::new(1, Correlithm::midpoint(64).unwrap());
        assert!(PatternMiner::default()
            .mine(&[p.clone(), p])
            .unwrap()
            .is_empty());
    }
}
