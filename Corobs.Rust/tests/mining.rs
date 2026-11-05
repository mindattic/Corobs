use std::collections::HashMap;

use corobs::geometry::ncube;
use corobs::{CorobsError, Correlithm, Cue, PatternMiner, PlyPoint, RuleMiner, SeededPrng};

const N: usize = 64;

fn near(centre: &Correlithm, prng: &mut SeededPrng, jitter: f64) -> Correlithm {
    let c: Vec<f64> = centre
        .coordinates()
        .iter()
        .map(|v| (v + (prng.next_double() - 0.5) * 2.0 * jitter).clamp(0.0, 1.0))
        .collect();
    Correlithm::new(&c).unwrap()
}

fn random(prng: &mut SeededPrng) -> Correlithm {
    Correlithm::random(prng, N).unwrap()
}

#[test]
fn a_planted_cluster_among_random_points_is_the_only_pattern() {
    let mut prng = SeededPrng::new(100);
    let mut points: Vec<PlyPoint<i32>> = (0..1000)
        .map(|i| PlyPoint::new(i, random(&mut prng)))
        .collect();
    let centre = random(&mut prng);
    for i in 1000..1006 {
        points.push(PlyPoint::new(i, near(&centre, &mut prng, 0.05)));
    }

    let patterns = PatternMiner::new(6.0, 5).unwrap().mine(&points).unwrap();

    assert_eq!(patterns.len(), 1);
    let mut members = patterns[0].members().to_vec();
    members.sort();
    assert_eq!(members, (1000..1006).collect::<Vec<_>>());
    let floor = ncube::bit_content(N, ncube::distance_at_deviations(N, 6.0).unwrap()).unwrap();
    assert!(patterns[0].bits() > floor);
    assert!(patterns[0].radius() < patterns[0].mean_pair_distance());
}

#[test]
fn random_points_alone_yield_no_pattern() {
    let mut prng = SeededPrng::new(101);
    let points: Vec<PlyPoint<i32>> = (0..1500)
        .map(|i| PlyPoint::new(i, random(&mut prng)))
        .collect();
    assert!(PatternMiner::default().mine(&points).unwrap().is_empty());
}

#[test]
fn mining_is_deterministic() {
    let make = || {
        let mut p = SeededPrng::new(102);
        let mid = Correlithm::midpoint(N).unwrap();
        (0..300)
            .map(|i| {
                PlyPoint::new(
                    i,
                    if i < 8 {
                        near(&mid, &mut p, 0.05)
                    } else {
                        random(&mut p)
                    },
                )
            })
            .collect::<Vec<_>>()
    };
    let a = PatternMiner::default().mine(&make()).unwrap();
    let b = PatternMiner::default().mine(&make()).unwrap();
    assert_eq!(
        a.iter().map(|p| p.members().to_vec()).collect::<Vec<_>>(),
        b.iter().map(|p| p.members().to_vec()).collect::<Vec<_>>()
    );
    assert_eq!(
        a.iter().map(|p| p.bits()).collect::<Vec<_>>(),
        b.iter().map(|p| p.bits()).collect::<Vec<_>>()
    );
}

#[test]
fn a_rule_emerges_and_the_one_member_that_breaks_it_is_the_top_hit() {
    let mut prng = SeededPrng::new(103);
    let cs = random(&mut prng); // where the faction sits on ply s
    let ct = random(&mut prng); // where its turf sits on ply t

    let mut s = Vec::new();
    let mut t = Vec::new();
    for id in 1..=10 {
        s.push(PlyPoint::new(id, near(&cs, &mut prng, 0.05))); // ten members of one faction
    }
    for id in 1..=9 {
        t.push(PlyPoint::new(id, near(&ct, &mut prng, 0.05))); // nine share the turf
    }
    t.push(PlyPoint::new(10, random(&mut prng))); // one lives somewhere unrelated
    for id in 11..=40 {
        s.push(PlyPoint::new(id, random(&mut prng)));
        t.push(PlyPoint::new(id, random(&mut prng)));
    }

    let miner = PatternMiner::default();
    let ps = miner.mine(&s).unwrap();
    let pt = miner.mine(&t).unwrap();
    assert_eq!(ps.len(), 1);
    assert_eq!(pt.len(), 1);

    let rules = RuleMiner::new(0.8)
        .unwrap()
        .mine("faction", &ps, "turf", &pt)
        .unwrap();
    assert_eq!(rules.len(), 1);
    assert!((rules[0].support - 0.9).abs() <= 1e-9);

    let to_map = |ply: &[PlyPoint<i32>]| {
        ply.iter()
            .map(|p| (p.id, p.point.clone()))
            .collect::<HashMap<_, _>>()
    };
    let plies = HashMap::from([
        ("faction".to_string(), to_map(&s)),
        ("turf".to_string(), to_map(&t)),
    ]);
    let hits = Cue::default().find(&rules, &plies).unwrap();
    assert_eq!(hits.len(), 1);
    assert_eq!(hits[0].id, 10);
    assert_eq!(hits[0].rank, 1);
    assert!(hits[0].bits > 0.0);
    assert!(hits[0].target_distance > ncube::distance_at_deviations(N, 1.0).unwrap());
}

#[test]
fn a_rule_needs_support() {
    let mut prng = SeededPrng::new(104);
    let cs = random(&mut prng);
    let ct = random(&mut prng);
    let s: Vec<PlyPoint<i32>> = (1..=10)
        .map(|id| PlyPoint::new(id, near(&cs, &mut prng, 0.05)))
        .collect();
    let mut t: Vec<PlyPoint<i32>> = (1..=5)
        .map(|id| PlyPoint::new(id, near(&ct, &mut prng, 0.05)))
        .collect();
    t.extend((6..=10).map(|id| PlyPoint::new(id, random(&mut prng))));
    let miner = PatternMiner::default();
    let (ms, mt) = (miner.mine(&s).unwrap(), miner.mine(&t).unwrap());
    assert!(
        RuleMiner::new(0.8)
            .unwrap()
            .mine("a", &ms, "b", &mt)
            .unwrap()
            .is_empty(),
        "half the members is not a rule"
    );
    assert!(matches!(
        RuleMiner::default().mine("a", &ms, "a", &mt),
        Err(CorobsError::Argument(_))
    ));
}
