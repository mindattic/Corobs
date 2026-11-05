// Package seeding holds SeededPrng, the one deterministic random stream everything stochastic in
// COROBS draws from, so a space can be rebuilt bit for bit from its seed.
package seeding

import (
	"fmt"
	"math/bits"

	corobs "github.com/mindattic/Corobs/Corobs.Go"
)

// SeededPrng is xoshiro256** seeded through SplitMix64. The same seed yields the same sequence on
// every machine and runtime, unlike math/rand, whose algorithm is not a contract.
type SeededPrng struct {
	seed           int64
	s0, s1, s2, s3 uint64
}

// New returns a fresh stream seeded from seed; the same seed always produces the same sequence of
// NextUint64/NextDouble/Next calls.
func New(seed int64) *SeededPrng {
	x := uint64(seed)
	p := &SeededPrng{seed: seed}
	p.s0 = splitMix(&x)
	p.s1 = splitMix(&x)
	p.s2 = splitMix(&x)
	p.s3 = splitMix(&x)
	return p
}

// Seed is the root seed this stream (or Derive chain) was built from.
func (p *SeededPrng) Seed() int64 { return p.seed }

// Derive returns a child stream named by label: the same parent seed and label always give the
// same child, however many values the parent has produced. This is how a converter gets one fixed
// point per category value (PRNG(seed, ply, value)). The label is hashed as its UTF-8 bytes.
func (p *SeededPrng) Derive(label string) *SeededPrng {
	return New(int64(fnv1a64(p.seed, label)))
}

// NextUint64 is the next raw 64-bit word of the xoshiro256** stream.
func (p *SeededPrng) NextUint64() uint64 {
	result := bits.RotateLeft64(p.s1*5, 7) * 9
	t := p.s1 << 17
	p.s2 ^= p.s0
	p.s3 ^= p.s1
	p.s1 ^= p.s2
	p.s0 ^= p.s3
	p.s2 ^= t
	p.s3 = bits.RotateLeft64(p.s3, 45)
	return result
}

// NextDouble is uniform on [0, 1).
func (p *SeededPrng) NextDouble() float64 {
	return float64(p.NextUint64()>>11) * (1.0 / (1 << 53))
}

// Next is a uniform integer on [0, maxExclusive); maxExclusive must be positive.
func (p *SeededPrng) Next(maxExclusive int) (int, error) {
	if maxExclusive <= 0 {
		return 0, fmt.Errorf("%w: maxExclusive must be positive, got %d", corobs.ErrOutOfRange, maxExclusive)
	}
	return int(p.NextDouble() * float64(maxExclusive)), nil
}

func splitMix(x *uint64) uint64 {
	*x += 0x9E3779B97F4A7C15
	z := *x
	z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9
	z = (z ^ (z >> 27)) * 0x94D049BB133111EB
	return z ^ (z >> 31)
}

func fnv1a64(seed int64, label string) uint64 {
	h := uint64(14695981039346656037)
	s := uint64(seed)
	for i := 0; i < 8; i++ {
		h ^= uint64(byte(s >> (8 * i)))
		h *= 1099511628211
	}
	for i := 0; i < len(label); i++ {
		h ^= uint64(label[i])
		h *= 1099511628211
	}
	return h
}
