package seeding

import (
	"errors"
	"testing"

	corobs "github.com/mindattic/Corobs/Corobs.Go"
)

func TestSameSeedSameStream(t *testing.T) {
	a, b := New(42), New(42)
	for i := 0; i < 1000; i++ {
		if x, y := a.NextUint64(), b.NextUint64(); x != y {
			t.Fatalf("draw %d: %d != %d", i, x, y)
		}
	}
}

func TestDifferentSeedsDiffer(t *testing.T) {
	a, b := New(1), New(2)
	same := true
	for i := 0; i < 16; i++ {
		if a.NextUint64() != b.NextUint64() {
			same = false
		}
	}
	if same {
		t.Fatal("seeds 1 and 2 produced the same 16 words")
	}
}

func TestDoublesAreUniformOnTheUnitInterval(t *testing.T) {
	p := New(99)
	sum := 0.0
	const count = 20000
	for i := 0; i < count; i++ {
		x := p.NextDouble()
		if x < 0 || x >= 1 {
			t.Fatalf("draw %d = %v outside [0, 1)", i, x)
		}
		sum += x
	}
	if mean := sum / count; mean < 0.49 || mean > 0.51 {
		t.Fatalf("mean %v, want 0.5 +/- 0.01", mean)
	}
}

func TestDeriveIsDeterministicAndIndependentOfConsumption(t *testing.T) {
	a := New(5)
	a.NextUint64()
	a.NextUint64()
	b := New(5)
	if a.Derive("faction").Seed() != b.Derive("faction").Seed() {
		t.Fatal("same seed and label gave different children")
	}
	if a.Derive("faction").Seed() == b.Derive("turf").Seed() {
		t.Fatal("different labels gave the same child")
	}
	if a.Derive("faction").Seed() == a.Seed() {
		t.Fatal("a child shares its parent's seed")
	}
}

func TestNextIsInRangeAndRefusesNonPositiveBounds(t *testing.T) {
	p := New(3)
	for _, max := range []int{1, 2, 7, 1000} {
		for i := 0; i < 100; i++ {
			v, err := p.Next(max)
			if err != nil || v < 0 || v >= max {
				t.Fatalf("Next(%d) = %d, %v", max, v, err)
			}
		}
	}
	for _, bad := range []int{0, -1} {
		if _, err := p.Next(bad); !errors.Is(err, corobs.ErrOutOfRange) {
			t.Fatalf("Next(%d) error = %v, want ErrOutOfRange", bad, err)
		}
	}
}
