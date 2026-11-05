use corobs::SeededPrng;

#[test]
fn same_seed_same_stream() {
    let mut a = SeededPrng::new(42);
    let mut b = SeededPrng::new(42);
    for _ in 0..1000 {
        assert_eq!(a.next_u64(), b.next_u64());
    }
}

#[test]
fn different_seeds_differ() {
    let mut a = SeededPrng::new(1);
    let mut b = SeededPrng::new(2);
    let xa: Vec<u64> = (0..16).map(|_| a.next_u64()).collect();
    let xb: Vec<u64> = (0..16).map(|_| b.next_u64()).collect();
    assert_ne!(xa, xb);
}

#[test]
fn doubles_are_uniform_on_the_unit_interval() {
    let mut p = SeededPrng::new(99);
    let xs: Vec<f64> = (0..20000).map(|_| p.next_double()).collect();
    assert!(xs.iter().all(|x| (0.0..1.0).contains(x)));
    assert!((xs.iter().sum::<f64>() / xs.len() as f64 - 0.5).abs() <= 0.01);
}

#[test]
fn derive_is_deterministic_and_independent_of_consumption() {
    let mut a = SeededPrng::new(5);
    a.next_u64();
    a.next_u64();
    let b = SeededPrng::new(5);
    assert_eq!(a.derive("faction").seed(), b.derive("faction").seed());
    assert_ne!(a.derive("faction").seed(), b.derive("turf").seed());
    assert_ne!(a.derive("faction").seed(), a.seed());
}
