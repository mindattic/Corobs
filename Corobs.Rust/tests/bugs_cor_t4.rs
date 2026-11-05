//! COR-T4. Each test asserts an invariant, not an implementation. The old code these fixes replaced
//! lives only in the C# reference, behind its COROBS_BUG_* symbols; the proofs are in docs/BUGS.md.

use std::collections::{HashMap, HashSet};
use std::hash::Hash;

use corobs::geometry::ncube;
use corobs::{bench, CorobsError, Correlithm, PatternMiner, PlyPoint, SeededPrng, StringCo};

#[test]
fn threshold_no_pattern_member_is_linked_by_a_pair_short_of_the_required_sigma() {
    let n = 4;
    let miner = PatternMiner::new(6.0, 5).unwrap();
    assert!(
        ncube::distance_at_deviations(n, miner.min_deviations()).unwrap() < 0.0,
        "precondition: μ − 6σ < 0 at N = 4"
    );

    let points: Vec<PlyPoint<usize>> = (0..5)
        .map(|k| {
            PlyPoint::new(
                k,
                Correlithm::new(&[0.1 * k as f64, 0.5, 0.5, 0.5]).unwrap(),
            )
        })
        .collect();

    for pattern in miner.mine(&points).unwrap() {
        for &id in pattern.members() {
            let p = &points[id].point;
            let best = pattern
                .members()
                .iter()
                .filter(|&&o| o != id)
                .map(|&o| ncube::deviations_below(n, p.distance_to(&points[o].point)).unwrap())
                .fold(f64::NEG_INFINITY, f64::max);
            assert!(
                best >= miner.min_deviations(),
                "member {id} joined a {}σ pattern though its closest partner is only {best:.2}σ below μ",
                miner.min_deviations()
            );
        }
    }
}

fn ring_at_never_returns_a_point_off_the_ring(t: f64) {
    let n = 32;
    let ring = StringCo::ring(&mut SeededPrng::new(42), n).unwrap();

    let p = match ring.at(t) {
        Err(CorobsError::ArgumentOutOfRange(_)) => return,
        other => other.unwrap(),
    };

    // A ring takes exactly 2N distinct points, one per arc between its 2N breakpoints.
    let steps = 200_000;
    let on_ring: HashSet<Correlithm> = (0..steps)
        .map(|k| ring.at(k as f64 / steps as f64).unwrap())
        .collect();
    assert_eq!(
        on_ring.len(),
        2 * n,
        "precondition: the grid visits every ring point"
    );
    assert!(on_ring.contains(&p), "At({t}) returned a point the ring never visits (book Ch. IX, p. 123: exactly on the string)");
}

#[test]
fn ring_at_positive_infinity_never_returns_a_point_off_the_ring() {
    ring_at_never_returns_a_point_off_the_ring(f64::INFINITY);
}

#[test]
fn ring_at_negative_infinity_never_returns_a_point_off_the_ring() {
    ring_at_never_returns_a_point_off_the_ring(f64::NEG_INFINITY);
}

fn oracle<T, K>(pairs: &[(T, T)], key: impl Fn(&T) -> K) -> impl Fn(&T) -> Vec<T>
where
    T: Clone,
    K: Eq + Hash,
{
    let mut map: HashMap<K, Vec<T>> = HashMap::new();
    for (a, b) in pairs {
        map.entry(key(a)).or_default().push(b.clone());
        map.entry(key(b)).or_default().push(a.clone());
    }
    move |id| map.get(&key(id)).cloned().unwrap_or_default()
}

#[test]
fn pairs_a_perfect_predictor_recovers_every_hidden_relationship_even_when_listed_repeatedly() {
    let mut pairs = Vec::new();
    for i in 0..20 {
        pairs.push((2 * i, 2 * i + 1));
        pairs.push((2 * i, 2 * i + 1));
        pairs.push((2 * i + 1, 2 * i));
    }
    let r = bench::holdout_recall(&pairs, 0.5, 7, oracle(&pairs, |v: &i32| *v)).unwrap();
    assert_eq!(
        r.recall(),
        1.0,
        "perfect predictor scored recall {:.3} (hidden {}, recovered {})",
        r.recall(),
        r.hidden,
        r.recovered
    );
}

#[test]
fn pairs_one_relationship_under_the_callers_comparer_is_hidden_once() {
    let fold = |s: &String| s.to_lowercase();
    let mut pairs = Vec::new();
    for i in 0..20 {
        pairs.push((format!("a{i}"), format!("B{i}")));
        pairs.push((format!("b{i}"), format!("A{i}")));
    }
    let r = bench::holdout_recall_by(&pairs, 0.5, 7, oracle(&pairs, fold), fold).unwrap();
    assert_eq!(
        r.hidden, 10,
        "20 relationships, half hidden; each spelled two ways is still one relationship"
    );
}
