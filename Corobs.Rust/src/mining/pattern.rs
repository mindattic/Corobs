use std::collections::HashSet;
use std::fmt;
use std::hash::Hash;

use crate::geometry::Correlithm;

/// One thing's position on one ply (subspace).
#[derive(Clone, Debug, PartialEq)]
pub struct PlyPoint<TId> {
    /// The thing.
    pub id: TId,
    /// Its point on this ply.
    pub point: Correlithm,
}

impl<TId> PlyPoint<TId> {
    /// A thing's point on one ply.
    pub fn new(id: TId, point: Correlithm) -> Self {
        Self { id, point }
    }
}

/// An emergent truth: a set of things whose points on one ply lie far closer together than chance
/// allows. Proposed by [`PatternMiner`](crate::PatternMiner); what it *means*, and whether it is
/// true, is the caller's hand decision.
#[derive(Clone, Debug)]
pub struct Pattern<TId> {
    members: Vec<TId>,
    centroid: Correlithm,
    radius: f64,
    mean_pair_distance: f64,
    bits: f64,
    set: HashSet<TId>,
}

impl<TId: Eq + Hash + Clone> Pattern<TId> {
    /// A pattern over the given members and their already-computed geometry; callers normally get
    /// one from [`PatternMiner`](crate::PatternMiner) rather than constructing it directly.
    pub fn new(
        members: Vec<TId>,
        centroid: Correlithm,
        radius: f64,
        mean_pair_distance: f64,
        bits: f64,
    ) -> Self {
        let set = members.iter().cloned().collect();
        Self {
            members,
            centroid,
            radius,
            mean_pair_distance,
            bits,
            set,
        }
    }

    /// Whether `id` is one of this pattern's members.
    pub fn contains(&self, id: &TId) -> bool {
        self.set.contains(id)
    }
}

impl<TId> Pattern<TId> {
    /// The ids of the things in this cluster.
    pub fn members(&self) -> &[TId] {
        &self.members
    }

    /// The mean point of the members: what a rule's source or target pattern pulls toward.
    pub fn centroid(&self) -> &Correlithm {
        &self.centroid
    }

    /// The furthest any member lies from the centroid.
    pub fn radius(&self) -> f64 {
        self.radius
    }

    /// The mean distance between members, pairwise.
    pub fn mean_pair_distance(&self) -> f64 {
        self.mean_pair_distance
    }

    /// Eq. III-H bits of the mean pair distance: how far below chance this cluster is.
    pub fn bits(&self) -> f64 {
        self.bits
    }
}

impl<TId> fmt::Display for Pattern<TId> {
    /// The member count and bits, for logs and reports.
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "Pattern[{} members, {:.1} bits]",
            self.members.len(),
            self.bits
        )
    }
}
