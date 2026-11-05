package mining

import (
	"testing"

	"github.com/mindattic/Corobs/Corobs.Go/geometry"
)

// COR-T4 THRESHOLD (docs/BUGS.md): an invariant, not an implementation. No pattern member may be
// linked by a pair that falls short of the required sigma below standard distance.
func TestCorT4ThresholdNoPatternMemberIsLinkedByAPairShortOfTheRequiredSigma(t *testing.T) {
	const dims = 4
	miner, err := NewPatternMiner(6, 5)
	if err != nil {
		t.Fatal(err)
	}
	if !(geometry.DistanceAtDeviations(dims, miner.MinDeviations()) < 0) {
		t.Fatal("precondition: mu - 6 sigma < 0 at N = 4")
	}
	points := make([]PlyPoint[int], 5)
	for k := range points {
		p, err := geometry.NewCorrelithm([]float64{0.1 * float64(k), 0.5, 0.5, 0.5})
		if err != nil {
			t.Fatal(err)
		}
		points[k] = PlyPoint[int]{k, p}
	}
	for _, pattern := range Mine(miner, points) {
		for _, id := range pattern.Members() {
			p := points[id].Point
			best := -1e300
			for _, o := range pattern.Members() {
				if o != id {
					if d := geometry.DeviationsBelow(dims, p.DistanceTo(points[o].Point)); d > best {
						best = d
					}
				}
			}
			if best < miner.MinDeviations() {
				t.Fatalf("member %d joined a %v sigma pattern though its closest partner is only %.2f sigma below mu", id, miner.MinDeviations(), best)
			}
		}
	}
}
