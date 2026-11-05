package mining

import (
	"errors"
	"math"
	"slices"
	"testing"

	corobs "github.com/mindattic/Corobs/Corobs.Go"
	"github.com/mindattic/Corobs/Corobs.Go/geometry"
	"github.com/mindattic/Corobs/Corobs.Go/seeding"
)

const n = 64

func near(t *testing.T, centre geometry.Correlithm, prng *seeding.SeededPrng, jitter float64) geometry.Correlithm {
	t.Helper()
	c := make([]float64, centre.Dimensions())
	for i := range c {
		c[i] = math.Min(1, math.Max(0, centre.At(i)+float64((prng.NextDouble()-0.5)*2*jitter)))
	}
	p, err := geometry.NewCorrelithm(c)
	if err != nil {
		t.Fatal(err)
	}
	return p
}

func ids(from, count int) []int {
	out := make([]int, count)
	for i := range out {
		out[i] = from + i
	}
	return out
}

func TestAPlantedClusterAmongRandomPointsIsTheOnlyPattern(t *testing.T) {
	prng := seeding.New(100)
	var points []PlyPoint[int]
	for i := 0; i < 1000; i++ {
		points = append(points, PlyPoint[int]{i, geometry.Random(prng, n)})
	}
	centre := geometry.Random(prng, n)
	for i := 1000; i < 1006; i++ {
		points = append(points, PlyPoint[int]{i, near(t, centre, prng, 0.05)})
	}
	miner, err := NewPatternMiner(6, 5)
	if err != nil {
		t.Fatal(err)
	}
	patterns := Mine(miner, points)
	if len(patterns) != 1 {
		t.Fatalf("%d patterns, want 1", len(patterns))
	}
	members := patterns[0].Members()
	slices.Sort(members)
	if !slices.Equal(members, ids(1000, 6)) {
		t.Fatalf("members %v", members)
	}
	if !(patterns[0].Bits() > geometry.BitContent(n, geometry.DistanceAtDeviations(n, 6))) {
		t.Fatal("pattern bits must exceed the 6 sigma line")
	}
	if !(patterns[0].Radius() < patterns[0].MeanPairDistance()) {
		t.Fatal("radius must be below the mean pair distance")
	}
}

func TestRandomPointsAloneYieldNoPattern(t *testing.T) {
	prng := seeding.New(101)
	points := make([]PlyPoint[int], 1500)
	for i := range points {
		points[i] = PlyPoint[int]{i, geometry.Random(prng, n)}
	}
	if got := Mine(DefaultPatternMiner(), points); len(got) != 0 {
		t.Fatalf("%d patterns among random points", len(got))
	}
}

func TestMiningIsDeterministic(t *testing.T) {
	build := func() []PlyPoint[int] {
		p := seeding.New(102)
		out := make([]PlyPoint[int], 300)
		for i := range out {
			if i < 8 {
				out[i] = PlyPoint[int]{i, near(t, geometry.Midpoint(n), p, 0.05)}
			} else {
				out[i] = PlyPoint[int]{i, geometry.Random(p, n)}
			}
		}
		return out
	}
	a, b := Mine(DefaultPatternMiner(), build()), Mine(DefaultPatternMiner(), build())
	if len(a) != len(b) {
		t.Fatal("pattern counts differ")
	}
	for i := range a {
		if !slices.Equal(a[i].Members(), b[i].Members()) || a[i].Bits() != b[i].Bits() {
			t.Fatalf("pattern %d differs", i)
		}
	}
}

func TestARuleEmergesAndTheOneMemberThatBreaksItIsTheTopHit(t *testing.T) {
	prng := seeding.New(103)
	cs := geometry.Random(prng, n) // where the faction sits on ply s
	ct := geometry.Random(prng, n) // where its turf sits on ply t

	var s, tp []PlyPoint[int]
	for id := 1; id <= 10; id++ { // ten members of one faction
		s = append(s, PlyPoint[int]{id, near(t, cs, prng, 0.05)})
	}
	for id := 1; id <= 9; id++ { // nine share the turf
		tp = append(tp, PlyPoint[int]{id, near(t, ct, prng, 0.05)})
	}
	tp = append(tp, PlyPoint[int]{10, geometry.Random(prng, n)}) // one lives somewhere unrelated
	for id := 11; id <= 40; id++ {
		s = append(s, PlyPoint[int]{id, geometry.Random(prng, n)})
		tp = append(tp, PlyPoint[int]{id, geometry.Random(prng, n)})
	}

	miner := DefaultPatternMiner()
	ps, pt := Mine(miner, s), Mine(miner, tp)
	if len(ps) != 1 || len(pt) != 1 {
		t.Fatalf("patterns: %d source, %d target; want 1 and 1", len(ps), len(pt))
	}
	rm, err := NewRuleMiner(0.8)
	if err != nil {
		t.Fatal(err)
	}
	rules, err := MineRules(rm, "faction", ps, "turf", pt)
	if err != nil || len(rules) != 1 {
		t.Fatalf("rules: %v %v", rules, err)
	}
	if math.Abs(rules[0].Support-0.9) > 1e-9 {
		t.Fatalf("support %v, want 0.9", rules[0].Support)
	}

	plies := map[string]map[int]geometry.Correlithm{"faction": {}, "turf": {}}
	for _, p := range s {
		plies["faction"][p.ID] = p.Point
	}
	for _, p := range tp {
		plies["turf"][p.ID] = p.Point
	}
	hits, err := Find(DefaultCue(), rules, plies)
	if err != nil || len(hits) != 1 {
		t.Fatalf("hits: %v %v", hits, err)
	}
	h := hits[0]
	if h.ID != 10 || h.Rank != 1 || !(h.Bits > 0) || !(h.TargetDistance > geometry.DistanceAtDeviations(n, 1)) {
		t.Fatalf("hit %+v", h)
	}
}

func TestARuleNeedsSupport(t *testing.T) {
	prng := seeding.New(104)
	cs, ct := geometry.Random(prng, n), geometry.Random(prng, n)
	var s, tp []PlyPoint[int]
	for id := 1; id <= 10; id++ {
		s = append(s, PlyPoint[int]{id, near(t, cs, prng, 0.05)})
	}
	for id := 1; id <= 5; id++ {
		tp = append(tp, PlyPoint[int]{id, near(t, ct, prng, 0.05)})
	}
	for id := 6; id <= 10; id++ {
		tp = append(tp, PlyPoint[int]{id, geometry.Random(prng, n)})
	}
	miner := DefaultPatternMiner()
	rm, _ := NewRuleMiner(0.8)
	rules, err := MineRules(rm, "a", Mine(miner, s), "b", Mine(miner, tp))
	if err != nil || len(rules) != 0 {
		t.Fatalf("half the members is not a rule: %v %v", rules, err)
	}
	if _, err := MineRules(DefaultRuleMiner(), "a", Mine(miner, s), "a", Mine(miner, tp)); !errors.Is(err, corobs.ErrArgument) {
		t.Fatalf("same ply: %v", err)
	}
}

func TestParametersAreValidated(t *testing.T) {
	if _, err := NewPatternMiner(0, 5); !errors.Is(err, corobs.ErrOutOfRange) {
		t.Fatal(err)
	}
	if _, err := NewPatternMiner(6, 1); !errors.Is(err, corobs.ErrOutOfRange) {
		t.Fatal(err)
	}
	for _, bad := range []float64{0, 1.5} {
		if _, err := NewRuleMiner(bad); !errors.Is(err, corobs.ErrOutOfRange) {
			t.Fatal(err)
		}
	}
	if _, err := NewCue(-1); !errors.Is(err, corobs.ErrOutOfRange) {
		t.Fatal(err)
	}
	rules := []*Rule[int]{{SourcePly: "s", Source: NewPattern([]int{1}, geometry.Midpoint(4), 0, 0, 0, nil), TargetPly: "t", Target: NewPattern([]int{1}, geometry.Midpoint(4), 0, 0, 0, nil)}}
	if _, err := Find(DefaultCue(), rules, map[string]map[int]geometry.Correlithm{"s": {}}); !errors.Is(err, corobs.ErrArgument) {
		t.Fatalf("missing ply: %v", err)
	}
}

func TestPatternContainsUsesTheCallersKey(t *testing.T) {
	p := NewPattern([]string{"Alpha", "beta"}, geometry.Midpoint(4), 0, 0, 0, func(s string) string {
		b := []byte(s)
		for i, c := range b {
			if c >= 'a' && c <= 'z' {
				b[i] = c - 32
			}
		}
		return string(b)
	})
	if !p.Contains("ALPHA") || !p.Contains("Beta") || p.Contains("gamma") {
		t.Fatal("key equality")
	}
	if NewPattern([]string{"Alpha"}, geometry.Midpoint(4), 0, 0, 0, nil).Contains("alpha") {
		t.Fatal("nil key means ==")
	}
}
