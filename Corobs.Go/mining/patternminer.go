package mining

import (
	"cmp"
	"fmt"
	"slices"

	corobs "github.com/mindattic/Corobs/Corobs.Go"
	"github.com/mindattic/Corobs/Corobs.Go/geometry"
)

// PatternMiner finds the clusters on one ply that are far tighter than chance: two points are
// linked when they lie at least MinDeviations sigma below standard distance (~52 bits at 6 sigma,
// Eq. III-H), linked points are joined by union-find, and a component with at least MinMembers
// members is a proposed Pattern. Deterministic: points are processed in id order, and the output is
// ordered by bits then by first member.
type PatternMiner struct {
	minDeviations float64
	minMembers    int
}

// NewPatternMiner returns a miner that links points at minDeviations sigma (> 0) below standard
// distance and keeps clusters of at least minMembers (>= 2).
func NewPatternMiner(minDeviations float64, minMembers int) (*PatternMiner, error) {
	if minDeviations <= 0 {
		return nil, fmt.Errorf("%w: minDeviations must be positive, got %v", corobs.ErrOutOfRange, minDeviations)
	}
	if minMembers < 2 {
		return nil, fmt.Errorf("%w: minMembers must be at least 2, got %d", corobs.ErrOutOfRange, minMembers)
	}
	return &PatternMiner{minDeviations: minDeviations, minMembers: minMembers}, nil
}

// DefaultPatternMiner links at 6 sigma (~52 bits) and keeps clusters of at least 5.
func DefaultPatternMiner() *PatternMiner { return &PatternMiner{minDeviations: 6, minMembers: 5} }

// MinDeviations is the linking threshold, in sigma below standard distance.
func (m *PatternMiner) MinDeviations() float64 { return m.minDeviations }

// MinMembers is the smallest cluster size kept as a pattern.
func (m *PatternMiner) MinMembers() int { return m.minMembers }

// Mine returns the patterns found among points (all on the same ply), ordered by bits descending
// then by first member in natural order. Member equality is ==.
func Mine[TId cmp.Ordered](m *PatternMiner, points []PlyPoint[TId]) []*Pattern[TId] {
	return MineFunc(m, points, cmp.Compare[TId], nil)
}

// MineFunc is Mine with the caller's id order (compare, like slices.SortFunc) and member equality
// (key, passed through to each Pattern; nil means ==).
func MineFunc[TId comparable](m *PatternMiner, points []PlyPoint[TId], compare func(a, b TId) int, key func(TId) string) []*Pattern[TId] {
	if len(points) < m.minMembers {
		return []*Pattern[TId]{}
	}
	n := points[0].Point.Dimensions()
	sorted := slices.Clone(points)
	slices.SortStableFunc(sorted, func(a, b PlyPoint[TId]) int { return compare(a.ID, b.ID) })
	threshold := geometry.DistanceAtDeviations(n, m.minDeviations)
	// COR-T4 (docs/BUGS.md): distance is never negative, so a negative threshold links nothing.
	if threshold < 0 {
		return []*Pattern[TId]{}
	}
	thresholdSq := threshold * threshold

	parent := make([]int, len(sorted))
	for i := range parent {
		parent[i] = i
	}
	for i := range sorted {
		pi := sorted[i].Point
		for j := i + 1; j < len(sorted); j++ {
			if pi.SquaredDistanceTo(sorted[j].Point) <= thresholdSq {
				union(parent, i, j)
			}
		}
	}

	// Groups in order of their first (sorted) member, as the reference's insertion-ordered dictionary.
	var roots []int
	groups := map[int][]int{}
	for i := range sorted {
		root := find(parent, i)
		if _, ok := groups[root]; !ok {
			roots = append(roots, root)
		}
		groups[root] = append(groups[root], i)
	}

	result := []*Pattern[TId]{}
	for _, root := range roots {
		members := groups[root]
		if len(members) < m.minMembers {
			continue
		}
		pts := make([]geometry.Correlithm, len(members))
		ids := make([]TId, len(members))
		for k, i := range members {
			pts[k] = sorted[i].Point
			ids[k] = sorted[i].ID
		}
		centroid, err := geometry.Centroid(pts)
		if err != nil {
			panic(err) // unreachable: members is non-empty and every point shares the ply's dimensionality
		}
		radius := pts[0].DistanceTo(centroid)
		for _, p := range pts[1:] {
			if d := p.DistanceTo(centroid); d > radius {
				radius = d
			}
		}
		sum, pairs := 0.0, 0
		for a := 0; a < len(pts); a++ {
			for b := a + 1; b < len(pts); b++ {
				sum += pts[a].DistanceTo(pts[b])
				pairs++
			}
		}
		mean := sum / float64(pairs)
		result = append(result, NewPattern(ids, centroid, radius, mean, geometry.BitContent(n, mean), key))
	}

	slices.SortStableFunc(result, func(a, b *Pattern[TId]) int {
		if c := cmp.Compare(b.bits, a.bits); c != 0 {
			return c
		}
		return compare(a.members[0], b.members[0])
	})
	return result
}

func find(parent []int, i int) int {
	for parent[i] != i {
		parent[i] = parent[parent[i]]
		i = parent[i]
	}
	return i
}

func union(parent []int, a, b int) {
	ra, rb := find(parent, a), find(parent, b)
	if ra == rb {
		return
	}
	if ra < rb {
		parent[rb] = ra
	} else {
		parent[ra] = rb
	}
}
