package bench

import (
	"fmt"
	"strings"
	"testing"
)

// COR-T4 PAIRS (docs/BUGS.md): invariants of recall, not an implementation. A relationship is an
// unordered pair under the caller's equality; a perfect predictor's recall is 1 by definition.

func TestCorT4PairsAPerfectPredictorRecoversEveryHiddenRelationshipEvenWhenListedRepeatedly(t *testing.T) {
	var pairs []Pair[int]
	for i := 0; i < 20; i++ {
		pairs = append(pairs, Pair[int]{2 * i, 2*i + 1}, Pair[int]{2 * i, 2*i + 1}, Pair[int]{2*i + 1, 2 * i})
	}
	r, err := HoldoutRecall(pairs, 0.5, 7, oracle(pairs, func(i int) int { return i }))
	if err != nil {
		t.Fatal(err)
	}
	if r.Recall() != 1 {
		t.Fatalf("perfect predictor scored recall %.3f (hidden %d, recovered %d)", r.Recall(), r.Hidden, r.Recovered)
	}
}

func TestCorT4PairsOneRelationshipUnderTheCallersComparerIsHiddenOnce(t *testing.T) {
	key := strings.ToUpper // the counterpart of C# StringComparer.OrdinalIgnoreCase for these ids
	var pairs []Pair[string]
	for i := 0; i < 20; i++ {
		pairs = append(pairs, Pair[string]{fmt.Sprintf("a%d", i), fmt.Sprintf("B%d", i)}, Pair[string]{fmt.Sprintf("b%d", i), fmt.Sprintf("A%d", i)})
	}
	r, err := HoldoutRecallFunc(pairs, 0.5, 7, oracle(pairs, key), key)
	if err != nil {
		t.Fatal(err)
	}
	if r.Hidden != 10 {
		t.Fatalf("hidden %d: 20 relationships, half hidden; each spelled two ways is still one relationship", r.Hidden)
	}
}

func oracle[T any, K comparable](pairs []Pair[T], key func(T) K) func(T) []T {
	m := map[K][]T{}
	for _, p := range pairs {
		m[key(p.A)] = append(m[key(p.A)], p.B)
		m[key(p.B)] = append(m[key(p.B)], p.A)
	}
	return func(id T) []T { return m[key(id)] }
}
