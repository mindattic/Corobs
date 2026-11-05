// Package bench scores any way of relating things against any other on the same ground truth: the
// old way and the COROBS way answer the same questions, and these are the questions. Everything
// here is arithmetic over ids; the caller supplies the truth and the predictors.
package bench

import (
	"fmt"
	"math"
	"unicode/utf16"

	corobs "github.com/mindattic/Corobs/Corobs.Go"
	"github.com/mindattic/Corobs/Corobs.Go/seeding"
)

// Pair is one relationship between two things. Pairs are unordered: (a, b) and (b, a) are one.
type Pair[TId any] struct{ A, B TId }

// RecallResult is how well a neighbour function recovers relationships that were hidden from it.
type RecallResult struct {
	Hidden, Recovered, Predicted, PredictedTrue int
}

// Recall is the share of the hidden pairs that the predictor recovered.
func (r RecallResult) Recall() float64 {
	if r.Hidden == 0 {
		return 0
	}
	return float64(r.Recovered) / float64(r.Hidden)
}

// Precision is the share of the predictor's own guesses that were actually true (anywhere in the
// full truth).
func (r RecallResult) Precision() float64 {
	if r.Predicted == 0 {
		return 0
	}
	return float64(r.PredictedTrue) / float64(r.Predicted)
}

// ReachResult is how far a thing can reach through a relationship: mean reachable count per hop and
// how many things reach nothing at all (dead records).
type ReachResult struct {
	MeanReachableByHop []float64
	Isolated, Total    int
}

// HoldoutRecall hides holdoutFraction (in (0, 1)) of the distinct true relationships
// (deterministically, by seed; round half to even), asks neighbours for each hidden endpoint's
// neighbours, and counts how many hidden pairs come back. Precision counts predicted neighbours of
// those endpoints that are true pairs anywhere in the full truth. Ids are equal under ==.
func HoldoutRecall[TId comparable](truePairs []Pair[TId], holdoutFraction float64, seed int64, neighbours func(TId) []TId) (RecallResult, error) {
	return HoldoutRecallFunc(truePairs, holdoutFraction, seed, neighbours, func(id TId) TId { return id })
}

// HoldoutRecallFunc is HoldoutRecall with the caller's equality: two ids are the same thing when
// key gives the same value (the counterpart of a C# IEqualityComparer).
func HoldoutRecallFunc[TId any, K comparable](truePairs []Pair[TId], holdoutFraction float64, seed int64, neighbours func(TId) []TId, key func(TId) K) (RecallResult, error) {
	if holdoutFraction <= 0 || holdoutFraction >= 1 {
		return RecallResult{}, fmt.Errorf("%w: holdoutFraction must lie in (0, 1), got %v", corobs.ErrOutOfRange, holdoutFraction)
	}
	truth := newPairSet(key)
	for _, p := range truePairs {
		truth.add(canon(p))
	}

	prng := seeding.New(seed)
	// COR-T4 (docs/BUGS.md): a pair listed twice, or both ways round, is one relationship to hide.
	distinct := newPairSet(key)
	var shuffled []Pair[TId]
	for _, p := range truePairs {
		c := canon(p)
		if distinct.add(c) {
			shuffled = append(shuffled, c)
		}
	}
	for i := len(shuffled) - 1; i > 0; i-- {
		j, _ := prng.Next(i + 1)
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	}
	hiddenCount := int(math.RoundToEven(float64(len(shuffled)) * holdoutFraction))
	hidden := make([]Pair[TId], hiddenCount)
	for i := range hidden {
		hidden[i] = canon(shuffled[i])
	}
	hiddenSet := newPairSet(key)
	for _, p := range hidden {
		hiddenSet.add(p)
	}

	recovered, predicted, predictedTrue := 0, 0, 0
	var endpoints []TId
	seenEndpoint := map[K]struct{}{}
	for _, p := range hidden {
		for _, e := range [2]TId{p.A, p.B} {
			if _, ok := seenEndpoint[key(e)]; !ok {
				seenEndpoint[key(e)] = struct{}{}
				endpoints = append(endpoints, e)
			}
		}
	}
	seen := newPairSet(key)
	for _, e := range endpoints {
		for _, nb := range neighbours(e) {
			pair := canon(Pair[TId]{e, nb})
			if !seen.add(pair) {
				continue
			}
			predicted++
			if truth.contains(pair) {
				predictedTrue++
			}
			if hiddenSet.remove(pair) {
				recovered++
			}
		}
	}
	return RecallResult{Hidden: len(hidden), Recovered: recovered, Predicted: predicted, PredictedTrue: predictedTrue}, nil
}

// Reach runs a breadth-first reach from every id through adjacency, up to maxHops (> 0). Ids are
// equal under ==.
func Reach[TId comparable](ids []TId, adjacency func(TId) []TId, maxHops int) (ReachResult, error) {
	return ReachFunc(ids, adjacency, maxHops, func(id TId) TId { return id })
}

// ReachFunc is Reach with the caller's equality (key, as in HoldoutRecallFunc).
func ReachFunc[TId any, K comparable](ids []TId, adjacency func(TId) []TId, maxHops int, key func(TId) K) (ReachResult, error) {
	if maxHops <= 0 {
		return ReachResult{}, fmt.Errorf("%w: maxHops must be positive, got %d", corobs.ErrOutOfRange, maxHops)
	}
	sums := make([]float64, maxHops)
	isolated := 0
	for _, start := range ids {
		visited := map[K]struct{}{key(start): {}}
		frontier := []TId{start}
		reached := 0
		for hop := 0; hop < maxHops; hop++ {
			var next []TId
			for _, f := range frontier {
				for _, a := range adjacency(f) {
					if _, ok := visited[key(a)]; !ok {
						visited[key(a)] = struct{}{}
						next = append(next, a)
					}
				}
			}
			reached += len(next)
			sums[hop] += float64(reached)
			frontier = next
			if len(next) == 0 {
				for h := hop + 1; h < maxHops; h++ {
					sums[h] += float64(reached)
				}
				break
			}
		}
		if reached == 0 {
			isolated++
		}
	}
	means := make([]float64, maxHops)
	for i, s := range sums {
		if len(ids) != 0 {
			means[i] = s / float64(len(ids))
		}
	}
	return ReachResult{MeanReachableByHop: means, Isolated: isolated, Total: len(ids)}, nil
}

// CascadeYield is hits that closed because something else was fixed, per direct fix. The old way
// scores zero by construction; that is a fact to report, not to hide.
func CascadeYield(closedByCascade, directFixes int) float64 {
	if directFixes == 0 {
		return 0
	}
	return float64(closedByCascade) / float64(directFixes)
}

// canon puts a pair in the reference's canonical order: by the ids' text compared ordinally, as C#
// string.CompareOrdinal(a.ToString(), b.ToString()) does, i.e. by UTF-16 code units.
func canon[TId any](p Pair[TId]) Pair[TId] {
	if compareOrdinal(fmt.Sprint(p.A), fmt.Sprint(p.B)) <= 0 {
		return p
	}
	return Pair[TId]{p.B, p.A}
}

func compareOrdinal(a, b string) int {
	ua, ub := utf16.Encode([]rune(a)), utf16.Encode([]rune(b))
	for i := 0; i < len(ua) && i < len(ub); i++ {
		if ua[i] != ub[i] {
			return int(ua[i]) - int(ub[i])
		}
	}
	return len(ua) - len(ub)
}

// pairSet holds unordered pairs under a key: (a, b) and (b, a) are one entry, as the reference's
// PairComparer makes them.
type pairSet[TId any, K comparable] struct {
	key func(TId) K
	m   map[[2]K]struct{}
}

func newPairSet[TId any, K comparable](key func(TId) K) *pairSet[TId, K] {
	return &pairSet[TId, K]{key: key, m: map[[2]K]struct{}{}}
}

func (s *pairSet[TId, K]) find(p Pair[TId]) ([2]K, bool) {
	ka, kb := s.key(p.A), s.key(p.B)
	if _, ok := s.m[[2]K{ka, kb}]; ok {
		return [2]K{ka, kb}, true
	}
	if _, ok := s.m[[2]K{kb, ka}]; ok {
		return [2]K{kb, ka}, true
	}
	return [2]K{}, false
}

func (s *pairSet[TId, K]) contains(p Pair[TId]) bool { _, ok := s.find(p); return ok }

// add inserts p unless an equal pair is present, and reports whether it did.
func (s *pairSet[TId, K]) add(p Pair[TId]) bool {
	if s.contains(p) {
		return false
	}
	s.m[[2]K{s.key(p.A), s.key(p.B)}] = struct{}{}
	return true
}

// remove deletes the pair equal to p, and reports whether there was one.
func (s *pairSet[TId, K]) remove(p Pair[TId]) bool {
	k, ok := s.find(p)
	if ok {
		delete(s.m, k)
	}
	return ok
}
