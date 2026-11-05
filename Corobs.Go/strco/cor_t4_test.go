package strco

import (
	"errors"
	"fmt"
	"math"
	"strings"
	"testing"

	corobs "github.com/mindattic/Corobs/Corobs.Go"
	"github.com/mindattic/Corobs/Corobs.Go/geometry"
	"github.com/mindattic/Corobs/Corobs.Go/seeding"
)

// COR-T4 RING (docs/BUGS.md): an invariant, not an implementation. A continuous sensor's state
// point is "exactly on" the string (Ch. IX, p. 123), so At must never return a point off the ring.
func TestCorT4RingAtNeverReturnsAPointOffTheRing(t *testing.T) {
	const dims = 32
	ring := Ring(seeding.New(42), dims)
	for _, pos := range []float64{math.Inf(1), math.Inf(-1)} {
		p, err := ring.At(pos)
		if err != nil {
			if !errors.Is(err, corobs.ErrOutOfRange) {
				t.Fatalf("At(%v): unexpected error %v", pos, err)
			}
			continue
		}
		// A ring takes exactly 2N distinct points, one per arc between its 2N breakpoints.
		onRing := map[string]struct{}{}
		const steps = 200_000
		for k := 0; k < steps; k++ {
			onRing[key(at(t, ring, float64(k)/steps))] = struct{}{}
		}
		if len(onRing) != 2*dims {
			t.Fatalf("precondition: the grid visited %d ring points, want %d", len(onRing), 2*dims)
		}
		if _, ok := onRing[key(p)]; !ok {
			t.Fatalf("At(%v) returned a point the ring never visits (book Ch. IX, p. 123: exactly on the string)", pos)
		}
	}
}

func key(p geometry.Correlithm) string {
	var b strings.Builder
	for _, v := range p.Coordinates() {
		fmt.Fprintf(&b, "%016x", math.Float64bits(v))
	}
	return b.String()
}
