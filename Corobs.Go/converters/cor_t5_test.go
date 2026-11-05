package converters

import (
	"math"
	"testing"

	"github.com/mindattic/Corobs/Corobs.Go/seeding"
)

// COR-T5 is a decision, not a proven error (docs/BUGS.md): this test pins the chosen behaviour.
func TestCorT5DecisionAWrappingConverterMapsInfinityToMissing(t *testing.T) {
	for _, v := range []float64{math.Inf(1), math.Inf(-1)} {
		hours, err := NewContinuous(seeding.New(1), 32, 0, 24, true)
		if err != nil {
			t.Fatal(err)
		}
		p, err := hours.Convert(&v)
		if err != nil || !p.Equal(hours.Missing()) {
			t.Fatalf("Convert(%v) = %v, %v; want Missing", v, p, err)
		}
	}
}
