package mining

import (
	"cmp"
	"fmt"
	"slices"

	corobs "github.com/mindattic/Corobs/Corobs.Go"
)

// Rule is s.p >: t.q (Ch. IV): things inside pattern Source on ply SourcePly are found inside
// pattern Target on ply TargetPly with the given Support. These are the strings that pull.
type Rule[TId comparable] struct {
	SourcePly string
	Source    *Pattern[TId]
	TargetPly string
	Target    *Pattern[TId]
	Support   float64
	Bits      float64
}

// String gives the rule's plies, pattern sizes, support and bits, for logs and reports.
func (r *Rule[TId]) String() string {
	return fmt.Sprintf("%s.[%d] >: %s.[%d] support %.0f%%, %.1f bits", r.SourcePly, len(r.Source.members), r.TargetPly, len(r.Target.members), r.Support*100, r.Bits)
}

// RuleMiner proposes rules between the patterns of two plies: for every source pattern, the target
// pattern that holds the largest share of its members, kept when that share reaches MinSupport.
// Bits = support x the source pattern's bits. Deterministic.
type RuleMiner struct {
	minSupport float64
}

// NewRuleMiner returns a miner that proposes rules whose support reaches minSupport, in (0, 1].
func NewRuleMiner(minSupport float64) (*RuleMiner, error) {
	if minSupport <= 0 || minSupport > 1 {
		return nil, fmt.Errorf("%w: minSupport must lie in (0, 1], got %v", corobs.ErrOutOfRange, minSupport)
	}
	return &RuleMiner{minSupport: minSupport}, nil
}

// DefaultRuleMiner proposes rules with support of at least 0.8.
func DefaultRuleMiner() *RuleMiner { return &RuleMiner{minSupport: 0.8} }

// MinSupport is the smallest share of a source pattern's members that must land in the best target
// pattern for a rule to be proposed.
func (m *RuleMiner) MinSupport() float64 { return m.minSupport }

// MineRules returns the rules from sourcePly's patterns (source) to targetPly's (target) that reach
// MinSupport, ordered by bits descending (ties keep source order). The two plies must differ.
func MineRules[TId comparable](m *RuleMiner, sourcePly string, source []*Pattern[TId], targetPly string, target []*Pattern[TId]) ([]*Rule[TId], error) {
	if sourcePly == targetPly {
		return nil, fmt.Errorf("%w: a rule relates two different plies", corobs.ErrArgument)
	}
	rules := []*Rule[TId]{}
	for _, p := range source {
		var best *Pattern[TId]
		bestCount := 0
		for _, q := range target {
			count := 0
			for _, id := range p.members {
				if q.Contains(id) {
					count++
				}
			}
			if count > bestCount {
				best, bestCount = q, count
			}
		}
		if best == nil {
			continue
		}
		support := float64(bestCount) / float64(len(p.members))
		if support >= m.minSupport {
			rules = append(rules, &Rule[TId]{SourcePly: sourcePly, Source: p, TargetPly: targetPly, Target: best, Support: support, Bits: support * p.bits})
		}
	}
	slices.SortStableFunc(rules, func(a, b *Rule[TId]) int { return cmp.Compare(b.Bits, a.Bits) })
	return rules, nil
}
