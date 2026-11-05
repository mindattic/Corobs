// Package mining finds the truths nobody wrote down: PatternMiner proposes clusters far tighter than
// chance on one ply, RuleMiner proposes rules s.p >: t.q between plies (Ch. IV), and Cue ranks the
// things that sit inside a rule's source yet miss its target (Ch. X-XI). It measures; confirming a
// pattern or rule and resolving a hit are the caller's decisions.
package mining

import (
	"fmt"

	"github.com/mindattic/Corobs/Corobs.Go/geometry"
)

// PlyPoint is one thing's position on one ply (subspace).
type PlyPoint[TId any] struct {
	ID    TId
	Point geometry.Correlithm
}

// Pattern is an emergent truth: a set of things whose points on one ply lie far closer together
// than chance allows. Proposed by a PatternMiner; what it means, and whether it is true, is the
// caller's hand decision.
type Pattern[TId comparable] struct {
	members          []TId
	centroid         geometry.Correlithm
	radius           float64
	meanPairDistance float64
	bits             float64
	contains         func(TId) bool
}

// NewPattern returns a pattern over the given members and their already-computed geometry; callers
// normally get one from Mine rather than constructing it directly. key, when non-nil, defines
// member equality (the counterpart of a C# IEqualityComparer); nil means ==.
func NewPattern[TId comparable](members []TId, centroid geometry.Correlithm, radius, meanPairDistance, bits float64, key func(TId) string) *Pattern[TId] {
	p := &Pattern[TId]{members: append([]TId(nil), members...), centroid: centroid, radius: radius, meanPairDistance: meanPairDistance, bits: bits}
	if key == nil {
		set := make(map[TId]struct{}, len(members))
		for _, m := range members {
			set[m] = struct{}{}
		}
		p.contains = func(id TId) bool { _, ok := set[id]; return ok }
	} else {
		set := make(map[string]struct{}, len(members))
		for _, m := range members {
			set[key(m)] = struct{}{}
		}
		p.contains = func(id TId) bool { _, ok := set[key(id)]; return ok }
	}
	return p
}

// Members returns the ids of the things in this cluster, in order (a copy).
func (p *Pattern[TId]) Members() []TId { return append([]TId(nil), p.members...) }

// Centroid is the mean point of the members: what a rule's source or target pattern pulls toward.
func (p *Pattern[TId]) Centroid() geometry.Correlithm { return p.centroid }

// Radius is the furthest any member lies from the centroid.
func (p *Pattern[TId]) Radius() float64 { return p.radius }

// MeanPairDistance is the mean distance between members, pairwise.
func (p *Pattern[TId]) MeanPairDistance() float64 { return p.meanPairDistance }

// Bits is the Eq. III-H bits of the mean pair distance: how far below chance this cluster is.
func (p *Pattern[TId]) Bits() float64 { return p.bits }

// Contains reports whether id is one of this pattern's members.
func (p *Pattern[TId]) Contains(id TId) bool { return p.contains(id) }

// String gives the member count and bits, for logs and reports.
func (p *Pattern[TId]) String() string {
	return fmt.Sprintf("Pattern[%d members, %.1f bits]", len(p.members), p.bits)
}
