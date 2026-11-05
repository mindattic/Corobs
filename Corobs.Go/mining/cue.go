package mining

import (
	"cmp"
	"fmt"
	"slices"

	corobs "github.com/mindattic/Corobs/Corobs.Go"
	"github.com/mindattic/Corobs/Corobs.Go/geometry"
)

// Hit is a ranked contradiction candidate: a thing that sits inside a rule's source pattern yet
// lies at or near standard distance from the rule's target, the anomaly a cueing system hands to
// the expert (Ch. X-XI). What to do about it is the caller's hand decision.
type Hit[TId comparable] struct {
	ID             TId
	Rule           *Rule[TId]
	SourceDistance float64
	TargetDistance float64
	Bits           float64
	Rank           int
}

// String gives the hit's rank, id and bits against the rule it violates, for logs and reports.
func (h Hit[TId]) String() string {
	return fmt.Sprintf("#%d %v: %.1f bits — %s", h.Rank, h.ID, h.Bits, h.Rule)
}

// Cue finds, for every rule, every member of its source whose point on the target ply lies no
// closer than TargetDeviations sigma below standard distance from the target centroid: a hit.
// Bits = (bits of the member's own distance to the source centroid) x rule support, so a thing deep
// inside a strong source that misses the target outranks a marginal member of a weak one.
// Deterministic.
type Cue struct {
	targetDeviations float64
}

// NewCue returns a cueing instrument using targetDeviations (>= 0) as the pass/fail line.
func NewCue(targetDeviations float64) (*Cue, error) {
	if targetDeviations < 0 {
		return nil, fmt.Errorf("%w: targetDeviations must be non-negative, got %v", corobs.ErrOutOfRange, targetDeviations)
	}
	return &Cue{targetDeviations: targetDeviations}, nil
}

// DefaultCue uses 1 sigma below standard distance as the pass/fail line.
func DefaultCue() *Cue { return &Cue{targetDeviations: 1} }

// TargetDeviations is how close to the target centroid, in sigma below standard distance, a member
// must land to not count as a hit.
func (c *Cue) TargetDeviations() float64 { return c.targetDeviations }

// Find returns the hits for the confirmed rules, given each ply's points by id keyed by ply name,
// ordered by bits descending then id ascending, ranked from 1. A rule whose ply has no points is
// an error.
func Find[TId cmp.Ordered](c *Cue, rules []*Rule[TId], plies map[string]map[TId]geometry.Correlithm) ([]Hit[TId], error) {
	return FindFunc(c, rules, plies, cmp.Compare[TId])
}

// FindFunc is Find with the caller's tie-break order for ids at equal bits.
func FindFunc[TId comparable](c *Cue, rules []*Rule[TId], plies map[string]map[TId]geometry.Correlithm, compare func(a, b TId) int) ([]Hit[TId], error) {
	hits := []Hit[TId]{}
	for _, rule := range rules {
		sourcePoints, ok := plies[rule.SourcePly]
		if !ok {
			return nil, fmt.Errorf("%w: no points for ply '%s'", corobs.ErrArgument, rule.SourcePly)
		}
		targetPoints, ok := plies[rule.TargetPly]
		if !ok {
			return nil, fmt.Errorf("%w: no points for ply '%s'", corobs.ErrArgument, rule.TargetPly)
		}
		n := rule.Target.centroid.Dimensions()
		farEnough := geometry.DistanceAtDeviations(n, c.targetDeviations)
		for _, id := range rule.Source.members {
			tp, okT := targetPoints[id]
			sp, okS := sourcePoints[id]
			if !okT || !okS {
				continue
			}
			targetDistance := tp.DistanceTo(rule.Target.centroid)
			if targetDistance < farEnough {
				continue
			}
			sourceDistance := sp.DistanceTo(rule.Source.centroid)
			bits := geometry.BitContent(sp.Dimensions(), sourceDistance) * rule.Support
			hits = append(hits, Hit[TId]{ID: id, Rule: rule, SourceDistance: sourceDistance, TargetDistance: targetDistance, Bits: bits})
		}
	}
	slices.SortStableFunc(hits, func(a, b Hit[TId]) int {
		if r := cmp.Compare(b.Bits, a.Bits); r != 0 {
			return r
		}
		return compare(a.ID, b.ID)
	})
	for i := range hits {
		hits[i].Rank = i + 1
	}
	return hits, nil
}
