package bench

import (
	"errors"
	"fmt"
	"testing"

	corobs "github.com/mindattic/Corobs/Corobs.Go"
)

func TestHoldoutRecallCountsHiddenPairsThePredictorRecovers(t *testing.T) {
	var pairs []Pair[string]
	for i := 0; i < 20; i++ {
		pairs = append(pairs, Pair[string]{fmt.Sprintf("a%d", i), fmt.Sprintf("b%d", i)})
	}
	// A predictor that knows every pair recovers everything with perfect precision.
	all := map[string][]string{}
	for _, p := range pairs {
		all[p.A] = append(all[p.A], p.B)
		all[p.B] = append(all[p.B], p.A)
	}
	perfect, err := HoldoutRecall(pairs, 0.25, 1, func(id string) []string { return all[id] })
	if err != nil {
		t.Fatal(err)
	}
	if perfect.Hidden != 5 || perfect.Recall() != 1 || perfect.Precision() != 1 {
		t.Fatalf("perfect predictor: %+v", perfect)
	}
	// A predictor that knows nothing recovers nothing.
	blind, err := HoldoutRecall(pairs, 0.25, 1, func(string) []string { return nil })
	if err != nil || blind.Recall() != 0 {
		t.Fatalf("blind predictor: %+v %v", blind, err)
	}
	// Same seed, same hidden set.
	again, _ := HoldoutRecall(pairs, 0.25, 1, func(string) []string { return nil })
	if again.Hidden != blind.Hidden {
		t.Fatal("same seed, different hidden count")
	}
	for _, bad := range []float64{0, 1} {
		if _, err := HoldoutRecall(pairs, bad, 1, func(string) []string { return nil }); !errors.Is(err, corobs.ErrOutOfRange) {
			t.Fatalf("fraction %v: %v", bad, err)
		}
	}
}

func TestReachCountsHopsAndIsolatedRecords(t *testing.T) {
	adj := map[int][]int{1: {2}, 2: {1, 3}, 3: {2}, 4: {}}
	r, err := Reach([]int{1, 2, 3, 4}, func(id int) []int { return adj[id] }, 2)
	if err != nil {
		t.Fatal(err)
	}
	if r.Isolated != 1 || r.Total != 4 {
		t.Fatalf("%+v", r)
	}
	if r.MeanReachableByHop[0] != (1+2+1+0)/4.0 || r.MeanReachableByHop[1] != (2+2+2+0)/4.0 {
		t.Fatalf("means %v", r.MeanReachableByHop)
	}
	if _, err := Reach([]int{1}, func(int) []int { return nil }, 0); !errors.Is(err, corobs.ErrOutOfRange) {
		t.Fatalf("maxHops 0: %v", err)
	}
}

func TestCascadeYieldIsClosedByCascadePerDirectFix(t *testing.T) {
	if CascadeYield(6, 4) != 1.5 || CascadeYield(0, 0) != 0 {
		t.Fatal("cascade yield")
	}
}

func TestPairCanonCompareDecimalTextOrdinally(t *testing.T) {
	if got := canon(Pair[int]{9, 10}); got != (Pair[int]{10, 9}) {
		t.Fatalf("canon(9, 10) = %v; \"10\" sorts before \"9\"", got)
	}
	// U+FF5E (one UTF-16 unit, 0xFF5E) sorts after U+1F600 (surrogates 0xD83D...) in UTF-16 order,
	// though before it by code point.
	if compareOrdinal("～", "\U0001F600") <= 0 {
		t.Fatal("compareOrdinal must follow UTF-16 code units, as C# CompareOrdinal does")
	}
}
