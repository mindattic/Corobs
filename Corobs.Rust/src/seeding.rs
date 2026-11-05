//! Deterministic randomness: one seed rebuilds a whole space bit for bit.

use crate::error::{out_of_range, Result};

/// A deterministic pseudo-random stream (xoshiro256** seeded through SplitMix64). The same seed
/// yields the same doubles on every machine and in every language port. Everything stochastic in
/// COROBS draws from one of these, so a space can be rebuilt bit for bit from its seed.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct SeededPrng {
    s: [u64; 4],
    seed: i64,
}

impl SeededPrng {
    /// A fresh stream seeded from `seed`; the same seed always produces the same sequence of
    /// [`next_u64`](Self::next_u64) / [`next_double`](Self::next_double) / [`next_int`](Self::next_int) calls.
    pub fn new(seed: i64) -> Self {
        let mut x = seed as u64;
        let s0 = split_mix(&mut x);
        let s1 = split_mix(&mut x);
        let s2 = split_mix(&mut x);
        let s3 = split_mix(&mut x);
        Self {
            s: [s0, s1, s2, s3],
            seed,
        }
    }

    /// The root seed this stream (or [`derive`](Self::derive) chain) was built from.
    pub fn seed(&self) -> i64 {
        self.seed
    }

    /// A child stream named by `label`: the same parent seed and label always give the same child,
    /// however many values the parent has produced. This is how a converter gets one fixed point per
    /// category value (`PRNG(seed, ply, value)`). The label is hashed as UTF-8.
    pub fn derive(&self, label: &str) -> SeededPrng {
        SeededPrng::new(fnv1a64(self.seed, label) as i64)
    }

    /// The next raw 64-bit word of the xoshiro256** stream.
    pub fn next_u64(&mut self) -> u64 {
        let s = &mut self.s;
        let result = s[1].wrapping_mul(5).rotate_left(7).wrapping_mul(9);
        let t = s[1] << 17;
        s[2] ^= s[0];
        s[3] ^= s[1];
        s[1] ^= s[2];
        s[0] ^= s[3];
        s[2] ^= t;
        s[3] = s[3].rotate_left(45);
        result
    }

    /// Uniform on [0, 1): the top 53 bits of [`next_u64`](Self::next_u64) times 2⁻⁵³.
    pub fn next_double(&mut self) -> f64 {
        (self.next_u64() >> 11) as f64 * (1.0 / (1u64 << 53) as f64)
    }

    /// Uniform integer on [0, `max_exclusive`), by truncating `next_double() * max_exclusive`.
    pub fn next_int(&mut self, max_exclusive: i32) -> Result<i32> {
        if max_exclusive <= 0 {
            return out_of_range("max_exclusive must be positive");
        }
        Ok((self.next_double() * max_exclusive as f64) as i32)
    }
}

fn split_mix(x: &mut u64) -> u64 {
    *x = x.wrapping_add(0x9E37_79B9_7F4A_7C15);
    let mut z = *x;
    z = (z ^ (z >> 30)).wrapping_mul(0xBF58_476D_1CE4_E5B9);
    z = (z ^ (z >> 27)).wrapping_mul(0x94D0_49BB_1331_11EB);
    z ^ (z >> 31)
}

fn fnv1a64(seed: i64, label: &str) -> u64 {
    const PRIME: u64 = 1_099_511_628_211;
    let mut h: u64 = 14_695_981_039_346_656_037;
    for byte in (seed as u64).to_le_bytes() {
        h ^= u64::from(byte);
        h = h.wrapping_mul(PRIME);
    }
    for &byte in label.as_bytes() {
        h ^= u64::from(byte);
        h = h.wrapping_mul(PRIME);
    }
    h
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn next_int_refuses_a_non_positive_bound() {
        let mut p = SeededPrng::new(1);
        assert!(p.next_int(0).is_err());
        assert!(p.next_int(-3).is_err());
        assert!((0..100).all(|_| (0..7).contains(&p.next_int(7).unwrap())));
    }

    #[test]
    fn derive_hashes_the_label_as_utf8() {
        let p = SeededPrng::new(9);
        assert_ne!(p.derive("é").seed(), p.derive("e").seed());
        assert_eq!(
            p.derive("é").seed(),
            SeededPrng::new(9).derive("\u{e9}").seed()
        );
    }
}
