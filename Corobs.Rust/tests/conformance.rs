//! conformance/vectors.json is the C# reference's exact output; this port must reproduce it. Hex
//! strings are IEEE-754 bits and compare exactly; JSON numbers compare to 1e-12 relative error.
//! The schema and the cross-language traps are in conformance/README.md.

use std::collections::HashMap;
use std::fs;
use std::path::Path;
use std::sync::OnceLock;

use corobs::geometry::ncube;
use corobs::{
    bench, CardinalConverter, ContinuousConverter, Converter, Correlithm, Cue, OrdinalConverter,
    PatternMiner, PlanarConverter, PlyPoint, RuleMiner, SeededPrng, StringCo,
};
use serde_json::Value;

fn vectors() -> &'static Value {
    static V: OnceLock<Value> = OnceLock::new();
    V.get_or_init(|| {
        let path = Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("..")
            .join("conformance")
            .join("vectors.json");
        let text = fs::read_to_string(&path).unwrap_or_else(|e| panic!("{}: {e}", path.display()));
        serde_json::from_str(&text).unwrap()
    })
}

fn bits(v: &Value) -> u64 {
    u64::from_str_radix(v.as_str().expect("hex bits"), 16).unwrap()
}

fn f(v: &Value) -> f64 {
    f64::from_bits(bits(v))
}

fn num(v: &Value) -> f64 {
    v.as_f64().expect("number")
}

fn i64s(v: &Value) -> i64 {
    v.as_str().expect("decimal string").parse().unwrap()
}

fn u64s(v: &Value) -> u64 {
    v.as_str().expect("decimal string").parse().unwrap()
}

fn usz(v: &Value) -> usize {
    v.as_u64().expect("integer") as usize
}

fn exact(actual: f64, expected: &Value, what: &str) {
    assert_eq!(
        actual.to_bits(),
        bits(expected),
        "{what}: {actual:e} vs {:e}",
        f(expected)
    );
}

fn point(actual: &Correlithm, expected: &Value, what: &str) {
    let want: Vec<u64> = expected.as_array().unwrap().iter().map(bits).collect();
    let got: Vec<u64> = actual.coordinates().iter().map(|v| v.to_bits()).collect();
    assert_eq!(got, want, "{what}");
}

fn close(actual: f64, expected: f64, what: &str) {
    let diff = (actual - expected).abs();
    let ok =
        actual == expected || diff <= 1e-12 * actual.abs().max(expected.abs()) || diff <= 1e-300;
    assert!(ok, "{what}: {actual:e} vs {expected:e}");
}

fn arr(v: &Value) -> &Vec<Value> {
    v.as_array().unwrap()
}

#[test]
fn prng_streams_match() {
    for case in arr(&vectors()["prng"]) {
        let seed = i64s(&case["seed"]);
        let mut u = SeededPrng::new(seed);
        for (k, e) in arr(&case["uint64"]).iter().enumerate() {
            assert_eq!(u.next_u64(), u64s(e), "seed {seed} uint64[{k}]");
        }
        let mut d = SeededPrng::new(seed);
        for (k, e) in arr(&case["doubles"]).iter().enumerate() {
            exact(d.next_double(), e, &format!("seed {seed} double[{k}]"));
        }
        for next in arr(&case["next"]) {
            let max = next["max"].as_i64().unwrap() as i32;
            let mut p = SeededPrng::new(seed);
            for (k, e) in arr(&next["values"]).iter().enumerate() {
                assert_eq!(
                    i64::from(p.next_int(max).unwrap()),
                    e.as_i64().unwrap(),
                    "seed {seed} next({max})[{k}]"
                );
            }
        }
    }
}

#[test]
fn derive_matches() {
    for case in arr(&vectors()["derive"]) {
        let seed = i64s(&case["seed"]);
        let label = case["label"].as_str().unwrap();
        let mut child = SeededPrng::new(seed).derive(label);
        assert_eq!(
            child.seed(),
            i64s(&case["childSeed"]),
            "seed {seed} label {label:?}"
        );
        assert_eq!(
            child.derive("x").seed(),
            i64s(&case["grandchildSeed"]),
            "seed {seed} label {label:?} grandchild"
        );
        assert_eq!(
            child.next_u64(),
            u64s(&case["firstUint64"]),
            "seed {seed} label {label:?} first"
        );
    }
}

#[test]
fn ncube_statistics_match() {
    let v = &vectors()["ncube"];
    close(
        ncube::STANDARD_DEVIATION,
        num(&v["standardDeviation"]),
        "standardDeviation",
    );
    close(
        ncube::RADIUS_DEVIATION,
        num(&v["radiusDeviation"]),
        "radiusDeviation",
    );
    close(
        ncube::DIAMETER_DEVIATION,
        num(&v["diameterDeviation"]),
        "diameterDeviation",
    );
    for case in arr(&v["cases"]) {
        let n = usz(&case["n"]);
        close(
            ncube::standard_distance(n).unwrap(),
            num(&case["standardDistance"]),
            "standardDistance",
        );
        close(
            ncube::standard_radius(n).unwrap(),
            num(&case["standardRadius"]),
            "standardRadius",
        );
        close(
            ncube::standard_diameter(n).unwrap(),
            num(&case["standardDiameter"]),
            "standardDiameter",
        );
        close(
            ncube::corner_distance(n).unwrap(),
            num(&case["cornerDistance"]),
            "cornerDistance",
        );
        close(
            ncube::half_diagonal(n).unwrap(),
            num(&case["halfDiagonal"]),
            "halfDiagonal",
        );
        close(
            ncube::major_diagonal(n).unwrap(),
            num(&case["majorDiagonal"]),
            "majorDiagonal",
        );
        for d in arr(&case["distances"]) {
            let x = num(&d["distance"]);
            let at = format!("n {n} d {x}");
            close(
                ncube::deviations_below(n, x).unwrap(),
                num(&d["deviationsBelow"]),
                &format!("{at} deviationsBelow"),
            );
            close(
                ncube::bit_content(n, x).unwrap(),
                num(&d["bitContent"]),
                &format!("{at} bitContent"),
            );
            close(
                ncube::probability_of_proximity(n, x).unwrap(),
                num(&d["probabilityOfProximity"]),
                &format!("{at} probability"),
            );
            close(
                ncube::point_capacity(n, x).unwrap(),
                num(&d["pointCapacity"]),
                &format!("{at} pointCapacity"),
            );
        }
        for b in arr(&case["bitsToDistance"]) {
            close(
                ncube::distance_for_bits(n, num(&b["bits"])).unwrap(),
                num(&b["distanceForBits"]),
                "distanceForBits",
            );
        }
        for k in arr(&case["distanceAtDeviations"]) {
            close(
                ncube::distance_at_deviations(n, num(&k["deviations"])).unwrap(),
                num(&k["distance"]),
                "distanceAtDeviations",
            );
        }
    }
}

#[test]
fn correlithm_operations_match() {
    let v = &vectors()["correlithm"];
    let n = usz(&v["dimensions"]);
    let mut prng = SeededPrng::new(i64s(&v["seed"]));
    let a = Correlithm::random(&mut prng, n).unwrap();
    let b = Correlithm::random(&mut prng, n).unwrap();
    let mid = Correlithm::midpoint(n).unwrap();
    point(&a, &v["a"], "a");
    point(&b, &v["b"], "b");
    point(&mid, &v["midpoint"], "midpoint");
    exact(
        a.squared_distance_to(&b),
        &v["squaredDistance"],
        "squaredDistance",
    );
    exact(a.distance_to(&b), &v["distance"], "distance");
    point(
        &Correlithm::centroid([&a, &b, &mid]).unwrap(),
        &v["centroidOfABMidpoint"],
        "centroid",
    );
    for c in arr(&v["interpolate"]) {
        let fr = num(&c["fraction"]);
        point(
            &a.interpolate(&b, fr).unwrap(),
            &c["point"],
            &format!("interpolate {fr}"),
        );
    }
}

#[test]
fn string_cos_match() {
    let v = &vectors()["strings"];
    let n = usz(&v["dimensions"]);
    let seeded = |s: &Value| SeededPrng::new(i64s(&s["seed"]));

    let line = StringCo::line(&mut seeded(&v["line"]), n).unwrap();
    for c in arr(&v["line"]["at"]) {
        point(
            &line.at(f(&c["t"])).unwrap(),
            &c["point"],
            &format!("line at {}", f(&c["t"])),
        );
    }
    for key in ["atIndex", "atIndexSingle"] {
        for c in arr(&v["line"][key]) {
            point(
                &line.at_index(usz(&c["index"]), usz(&c["count"])).unwrap(),
                &c["point"],
                &format!("line {key} {c}"),
            );
        }
    }

    let ring = StringCo::ring(&mut seeded(&v["ring"]), n).unwrap();
    for c in arr(&v["ring"]["at"]) {
        point(
            &ring.at(f(&c["t"])).unwrap(),
            &c["point"],
            &format!("ring at {}", f(&c["t"])),
        );
    }
    for c in arr(&v["ring"]["atIndex"]) {
        point(
            &ring.at_index(usz(&c["index"]), usz(&c["count"])).unwrap(),
            &c["point"],
            &format!("ring atIndex {c}"),
        );
    }

    let plane = StringCo::plane(&mut seeded(&v["plane"]), n).unwrap();
    for c in arr(&v["plane"]["at"]) {
        let (x, y) = (f(&c["x"]), f(&c["y"]));
        point(
            &plane.at_xy(x, y).unwrap(),
            &c["point"],
            &format!("plane at ({x}, {y})"),
        );
    }
}

#[test]
fn converters_match() {
    let v = &vectors()["converters"];
    let n = usz(&v["dimensions"]);
    let seeded = |s: &Value| SeededPrng::new(i64s(&s["seed"]));
    point(&Correlithm::midpoint(n).unwrap(), &v["missing"], "missing");

    let mut cardinal = CardinalConverter::<str>::new(&seeded(&v["cardinal"]), n).unwrap();
    for c in arr(&v["cardinal"]["cases"]) {
        let key = c["value"].as_str().unwrap();
        point(
            &cardinal.convert(Some(key)).unwrap(),
            &c["point"],
            &format!("cardinal {key:?}"),
        );
    }

    let order: Vec<String> = arr(&v["ordinal"]["order"])
        .iter()
        .map(|s| s.as_str().unwrap().to_string())
        .collect();
    let mut ordinal = OrdinalConverter::new(&mut seeded(&v["ordinal"]), n, &order).unwrap();
    for c in arr(&v["ordinal"]["cases"]) {
        let value = c["value"].as_str().unwrap().to_string();
        point(
            &ordinal.convert(Some(&value)).unwrap(),
            &c["point"],
            &format!("ordinal {value}"),
        );
    }

    for key in ["continuousLine", "continuousRing"] {
        let s = &v[key];
        let mut conv = ContinuousConverter::new(
            &mut seeded(s),
            n,
            num(&s["min"]),
            num(&s["max"]),
            s["wraps"].as_bool().unwrap(),
        )
        .unwrap();
        for c in arr(&s["cases"]) {
            let x = f(&c["value"]);
            point(
                &conv.convert(Some(&x)).unwrap(),
                &c["point"],
                &format!("{key} {x}"),
            );
        }
    }

    let p = &v["planar"];
    let mut planar = PlanarConverter::new(
        &mut seeded(p),
        n,
        num(&p["minX"]),
        num(&p["maxX"]),
        num(&p["minY"]),
        num(&p["maxY"]),
    )
    .unwrap();
    for c in arr(&p["cases"]) {
        let xy = (f(&c["x"]), f(&c["y"]));
        point(
            &planar.convert(Some(&xy)).unwrap(),
            &c["point"],
            &format!("planar {xy:?}"),
        );
    }
}

#[test]
fn mining_matches() {
    let v = &vectors()["mining"];
    let ply = |name: &str| -> Vec<PlyPoint<i64>> {
        arr(&v["plies"][name])
            .iter()
            .map(|p| {
                PlyPoint::new(
                    p["id"].as_i64().unwrap(),
                    Correlithm::new(&arr(&p["point"]).iter().map(f).collect::<Vec<_>>()).unwrap(),
                )
            })
            .collect()
    };
    let (faction, turf) = (ply("faction"), ply("turf"));
    let miner = PatternMiner::new(
        num(&v["patternMiner"]["minDeviations"]),
        usz(&v["patternMiner"]["minMembers"]),
    )
    .unwrap();
    let fp = miner.mine(&faction).unwrap();
    let tp = miner.mine(&turf).unwrap();

    for (name, got) in [("faction", &fp), ("turf", &tp)] {
        let want = arr(&v["patterns"][name]);
        assert_eq!(got.len(), want.len(), "{name} pattern count");
        for (k, (g, w)) in got.iter().zip(want).enumerate() {
            let members: Vec<i64> = arr(&w["members"])
                .iter()
                .map(|m| m.as_i64().unwrap())
                .collect();
            assert_eq!(g.members(), members.as_slice(), "{name}[{k}] members");
            point(
                g.centroid(),
                &w["centroid"],
                &format!("{name}[{k}] centroid"),
            );
            exact(g.radius(), &w["radius"], &format!("{name}[{k}] radius"));
            exact(
                g.mean_pair_distance(),
                &w["meanPairDistance"],
                &format!("{name}[{k}] meanPairDistance"),
            );
            close(g.bits(), num(&w["bits"]), &format!("{name}[{k}] bits"));
        }
    }

    let rules = RuleMiner::new(num(&v["ruleMiner"]["minSupport"]))
        .unwrap()
        .mine("faction", &fp, "turf", &tp)
        .unwrap();
    let want_rules = arr(&v["rules"]);
    assert_eq!(rules.len(), want_rules.len(), "rule count");
    let index_of = |patterns: &[corobs::Pattern<i64>], p: &corobs::Pattern<i64>| {
        patterns.iter().position(|q| q.members() == p.members())
    };
    for (k, (r, w)) in rules.iter().zip(want_rules).enumerate() {
        assert_eq!(
            r.source_ply,
            w["sourcePly"].as_str().unwrap(),
            "rule {k} sourcePly"
        );
        assert_eq!(
            r.target_ply,
            w["targetPly"].as_str().unwrap(),
            "rule {k} targetPly"
        );
        assert_eq!(
            index_of(&fp, &r.source),
            Some(usz(&w["sourcePattern"])),
            "rule {k} source"
        );
        assert_eq!(
            index_of(&tp, &r.target),
            Some(usz(&w["targetPattern"])),
            "rule {k} target"
        );
        close(r.support, num(&w["support"]), &format!("rule {k} support"));
        close(r.bits, num(&w["bits"]), &format!("rule {k} bits"));
    }

    let to_map = |points: &[PlyPoint<i64>]| {
        points
            .iter()
            .map(|p| (p.id, p.point.clone()))
            .collect::<HashMap<_, _>>()
    };
    let plies = HashMap::from([
        ("faction".to_string(), to_map(&faction)),
        ("turf".to_string(), to_map(&turf)),
    ]);
    let hits = Cue::new(num(&v["cue"]["targetDeviations"]))
        .unwrap()
        .find(&rules, &plies)
        .unwrap();
    let want_hits = arr(&v["hits"]);
    assert_eq!(hits.len(), want_hits.len(), "hit count");
    for (k, (h, w)) in hits.iter().zip(want_hits).enumerate() {
        assert_eq!(h.id, w["id"].as_i64().unwrap(), "hit {k} id");
        assert_eq!(
            rules.iter().position(|r| std::ptr::eq(r, h.rule)),
            Some(usz(&w["rule"])),
            "hit {k} rule"
        );
        exact(
            h.source_distance,
            &w["sourceDistance"],
            &format!("hit {k} sourceDistance"),
        );
        exact(
            h.target_distance,
            &w["targetDistance"],
            &format!("hit {k} targetDistance"),
        );
        close(h.bits, num(&w["bits"]), &format!("hit {k} bits"));
        assert_eq!(h.rank, usz(&w["rank"]), "hit {k} rank");
    }
}

fn adjacency(v: &Value) -> HashMap<i64, Vec<i64>> {
    v.as_object()
        .unwrap()
        .iter()
        .map(|(k, ns)| {
            (
                k.parse().unwrap(),
                arr(ns).iter().map(|x| x.as_i64().unwrap()).collect(),
            )
        })
        .collect()
}

#[test]
fn bench_matches() {
    let v = &vectors()["bench"];
    let pairs: Vec<(i64, i64)> = arr(&v["pairs"])
        .iter()
        .map(|p| (p[0].as_i64().unwrap(), p[1].as_i64().unwrap()))
        .collect();
    for c in arr(&v["holdoutRecall"]) {
        let name = c["predictor"].as_str().unwrap();
        let predictor = adjacency(&v["predictors"][name]);
        let frac = num(&c["holdoutFraction"]);
        let r = bench::holdout_recall(&pairs, frac, i64s(&c["seed"]), |id| {
            predictor.get(id).cloned().unwrap_or_default()
        })
        .unwrap();
        let w = &c["result"];
        let what = format!("{name} {frac}");
        assert_eq!(r.hidden, usz(&w["hidden"]), "{what} hidden");
        assert_eq!(r.recovered, usz(&w["recovered"]), "{what} recovered");
        assert_eq!(r.predicted, usz(&w["predicted"]), "{what} predicted");
        assert_eq!(
            r.predicted_true,
            usz(&w["predictedTrue"]),
            "{what} predictedTrue"
        );
    }

    let reach = &v["reach"];
    let adj = adjacency(&reach["adjacency"]);
    let mut ids: Vec<i64> = adj.keys().copied().collect();
    ids.sort();
    let r = bench::reach(&ids, |id| adj[id].clone(), usz(&reach["maxHops"])).unwrap();
    let want: Vec<f64> = arr(&reach["meanReachableByHop"]).iter().map(num).collect();
    assert_eq!(r.mean_reachable_by_hop.len(), want.len());
    for (k, (g, w)) in r.mean_reachable_by_hop.iter().zip(&want).enumerate() {
        close(*g, *w, &format!("reach hop {k}"));
    }
    assert_eq!(r.isolated, usz(&reach["isolated"]));
    assert_eq!(r.total, usz(&reach["total"]));

    for c in arr(&v["cascadeYield"]) {
        close(
            bench::cascade_yield(usz(&c["closedByCascade"]), usz(&c["directFixes"])),
            num(&c["yield"]),
            "cascadeYield",
        );
    }
}
