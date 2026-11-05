use std::collections::HashMap;

use corobs::bench;

#[test]
fn holdout_recall_counts_hidden_pairs_the_predictor_recovers() {
    let pairs: Vec<(String, String)> = (0..20)
        .map(|i| (format!("a{i}"), format!("b{i}")))
        .collect();
    // A predictor that knows every pair recovers everything with perfect precision.
    let mut all: HashMap<String, Vec<String>> = HashMap::new();
    for (a, b) in &pairs {
        all.entry(a.clone()).or_default().push(b.clone());
        all.entry(b.clone()).or_default().push(a.clone());
    }
    let perfect = bench::holdout_recall(&pairs, 0.25, 1, |id| {
        all.get(id).cloned().unwrap_or_default()
    })
    .unwrap();
    assert_eq!(perfect.hidden, 5);
    assert_eq!(perfect.recall(), 1.0);
    assert_eq!(perfect.precision(), 1.0);
    // A predictor that knows nothing recovers nothing.
    let blind = bench::holdout_recall(&pairs, 0.25, 1, |_| Vec::new()).unwrap();
    assert_eq!(blind.recall(), 0.0);
    // Same seed, same hidden set.
    assert_eq!(
        bench::holdout_recall(&pairs, 0.25, 1, |_| Vec::new())
            .unwrap()
            .hidden,
        blind.hidden
    );
}

#[test]
fn reach_counts_hops_and_isolated_records() {
    let adj: HashMap<i32, Vec<i32>> =
        HashMap::from([(1, vec![2]), (2, vec![1, 3]), (3, vec![2]), (4, vec![])]);
    let r = bench::reach(&[1, 2, 3, 4], |id| adj[id].clone(), 2).unwrap();
    assert_eq!(r.isolated, 1);
    assert_eq!(r.total, 4);
    assert_eq!(r.mean_reachable_by_hop[0], (1 + 2 + 1) as f64 / 4.0);
    assert_eq!(r.mean_reachable_by_hop[1], (2 + 2 + 2) as f64 / 4.0);
}

#[test]
fn cascade_yield_is_closed_by_cascade_per_direct_fix() {
    assert_eq!(bench::cascade_yield(6, 4), 1.5);
    assert_eq!(bench::cascade_yield(0, 0), 0.0);
}
