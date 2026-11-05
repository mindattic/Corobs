package corobs_test

import (
	"encoding/json"
	"math"
	"os"
	"slices"
	"sort"
	"strconv"
	"testing"

	"github.com/mindattic/Corobs/Corobs.Go/bench"
	"github.com/mindattic/Corobs/Corobs.Go/converters"
	"github.com/mindattic/Corobs/Corobs.Go/geometry"
	"github.com/mindattic/Corobs/Corobs.Go/mining"
	"github.com/mindattic/Corobs/Corobs.Go/seeding"
	"github.com/mindattic/Corobs/Corobs.Go/strco"
)

// conformance/vectors.json is the C# reference's exact output; conformance/README.md says how to
// compare it: hex strings are IEEE-754 bits and match exactly, JSON numbers within 1e-12 relative.

type vectors struct {
	Prng []struct {
		Seed    string   `json:"seed"`
		Uint64  []string `json:"uint64"`
		Doubles []string `json:"doubles"`
		Next    []struct {
			Max    int   `json:"max"`
			Values []int `json:"values"`
		} `json:"next"`
	} `json:"prng"`
	Derive []struct {
		Seed           string `json:"seed"`
		Label          string `json:"label"`
		ChildSeed      string `json:"childSeed"`
		FirstUint64    string `json:"firstUint64"`
		GrandchildSeed string `json:"grandchildSeed"`
	} `json:"derive"`
	NCube struct {
		StandardDeviation float64 `json:"standardDeviation"`
		RadiusDeviation   float64 `json:"radiusDeviation"`
		DiameterDeviation float64 `json:"diameterDeviation"`
		Cases             []struct {
			N                int     `json:"n"`
			StandardDistance float64 `json:"standardDistance"`
			StandardRadius   float64 `json:"standardRadius"`
			StandardDiameter float64 `json:"standardDiameter"`
			CornerDistance   float64 `json:"cornerDistance"`
			HalfDiagonal     float64 `json:"halfDiagonal"`
			MajorDiagonal    float64 `json:"majorDiagonal"`
			Distances        []struct {
				Distance               float64 `json:"distance"`
				DeviationsBelow        float64 `json:"deviationsBelow"`
				BitContent             float64 `json:"bitContent"`
				ProbabilityOfProximity float64 `json:"probabilityOfProximity"`
				PointCapacity          float64 `json:"pointCapacity"`
			} `json:"distances"`
			BitsToDistance []struct {
				Bits            float64 `json:"bits"`
				DistanceForBits float64 `json:"distanceForBits"`
			} `json:"bitsToDistance"`
			DistanceAtDeviations []struct {
				Deviations float64 `json:"deviations"`
				Distance   float64 `json:"distance"`
			} `json:"distanceAtDeviations"`
		} `json:"cases"`
	} `json:"ncube"`
	Correlithm struct {
		Seed                 string   `json:"seed"`
		Dimensions           int      `json:"dimensions"`
		A                    []string `json:"a"`
		B                    []string `json:"b"`
		Midpoint             []string `json:"midpoint"`
		SquaredDistance      string   `json:"squaredDistance"`
		Distance             string   `json:"distance"`
		CentroidOfABMidpoint []string `json:"centroidOfABMidpoint"`
		Interpolate          []struct {
			Fraction float64  `json:"fraction"`
			Point    []string `json:"point"`
		} `json:"interpolate"`
	} `json:"correlithm"`
	Strings struct {
		Dimensions int `json:"dimensions"`
		Line       struct {
			Seed          string    `json:"seed"`
			At            []atCase  `json:"at"`
			AtIndex       []idxCase `json:"atIndex"`
			AtIndexSingle []idxCase `json:"atIndexSingle"`
		} `json:"line"`
		Ring struct {
			Seed    string    `json:"seed"`
			At      []atCase  `json:"at"`
			AtIndex []idxCase `json:"atIndex"`
		} `json:"ring"`
		Plane struct {
			Seed string   `json:"seed"`
			At   []xyCase `json:"at"`
		} `json:"plane"`
	} `json:"strings"`
	Converters struct {
		Dimensions int      `json:"dimensions"`
		Missing    []string `json:"missing"`
		Cardinal   struct {
			Seed  string `json:"seed"`
			Cases []struct {
				Value string   `json:"value"`
				Point []string `json:"point"`
			} `json:"cases"`
		} `json:"cardinal"`
		Ordinal struct {
			Seed  string   `json:"seed"`
			Order []string `json:"order"`
			Cases []struct {
				Value string   `json:"value"`
				Point []string `json:"point"`
			} `json:"cases"`
		} `json:"ordinal"`
		ContinuousLine continuousCase `json:"continuousLine"`
		ContinuousRing continuousCase `json:"continuousRing"`
		Planar         struct {
			Seed  string   `json:"seed"`
			MinX  float64  `json:"minX"`
			MaxX  float64  `json:"maxX"`
			MinY  float64  `json:"minY"`
			MaxY  float64  `json:"maxY"`
			Cases []xyCase `json:"cases"`
		} `json:"planar"`
	} `json:"converters"`
	Mining struct {
		Dimensions   int `json:"dimensions"`
		PatternMiner struct {
			MinDeviations float64 `json:"minDeviations"`
			MinMembers    int     `json:"minMembers"`
		} `json:"patternMiner"`
		RuleMiner struct {
			MinSupport float64 `json:"minSupport"`
		} `json:"ruleMiner"`
		Cue struct {
			TargetDeviations float64 `json:"targetDeviations"`
		} `json:"cue"`
		Plies    map[string][]plyPointCase `json:"plies"`
		Patterns map[string][]struct {
			Members          []int    `json:"members"`
			Centroid         []string `json:"centroid"`
			Radius           string   `json:"radius"`
			MeanPairDistance string   `json:"meanPairDistance"`
			Bits             float64  `json:"bits"`
		} `json:"patterns"`
		Rules []struct {
			SourcePly     string  `json:"sourcePly"`
			SourcePattern int     `json:"sourcePattern"`
			TargetPly     string  `json:"targetPly"`
			TargetPattern int     `json:"targetPattern"`
			Support       float64 `json:"support"`
			Bits          float64 `json:"bits"`
		} `json:"rules"`
		Hits []struct {
			ID             int     `json:"id"`
			Rule           int     `json:"rule"`
			SourceDistance string  `json:"sourceDistance"`
			TargetDistance string  `json:"targetDistance"`
			Bits           float64 `json:"bits"`
			Rank           int     `json:"rank"`
		} `json:"hits"`
	} `json:"mining"`
	Bench struct {
		Pairs         [][2]int                    `json:"pairs"`
		Predictors    map[string]map[string][]int `json:"predictors"`
		HoldoutRecall []struct {
			Predictor       string  `json:"predictor"`
			HoldoutFraction float64 `json:"holdoutFraction"`
			Seed            string  `json:"seed"`
			Result          struct {
				Hidden        int `json:"hidden"`
				Recovered     int `json:"recovered"`
				Predicted     int `json:"predicted"`
				PredictedTrue int `json:"predictedTrue"`
			} `json:"result"`
		} `json:"holdoutRecall"`
		Reach struct {
			Adjacency          map[string][]int `json:"adjacency"`
			MaxHops            int              `json:"maxHops"`
			MeanReachableByHop []float64        `json:"meanReachableByHop"`
			Isolated           int              `json:"isolated"`
			Total              int              `json:"total"`
		} `json:"reach"`
		CascadeYield []struct {
			ClosedByCascade int     `json:"closedByCascade"`
			DirectFixes     int     `json:"directFixes"`
			Yield           float64 `json:"yield"`
		} `json:"cascadeYield"`
	} `json:"bench"`
}

type atCase struct {
	T     string   `json:"t"`
	Point []string `json:"point"`
}

type idxCase struct {
	Index int      `json:"index"`
	Count int      `json:"count"`
	Point []string `json:"point"`
}

type xyCase struct {
	X     string   `json:"x"`
	Y     string   `json:"y"`
	Point []string `json:"point"`
}

type continuousCase struct {
	Seed  string  `json:"seed"`
	Min   float64 `json:"min"`
	Max   float64 `json:"max"`
	Wraps bool    `json:"wraps"`
	Cases []struct {
		Value string   `json:"value"`
		Point []string `json:"point"`
	} `json:"cases"`
}

type plyPointCase struct {
	ID    int      `json:"id"`
	Point []string `json:"point"`
}

func load(t *testing.T) *vectors {
	t.Helper()
	raw, err := os.ReadFile("../conformance/vectors.json")
	if err != nil {
		t.Fatalf("read vectors (run build.ps1 -Profile Vectors): %v", err)
	}
	var v vectors
	if err := json.Unmarshal(raw, &v); err != nil {
		t.Fatal(err)
	}
	return &v
}

func bits(t *testing.T, hex string) float64 {
	t.Helper()
	u, err := strconv.ParseUint(hex, 16, 64)
	if err != nil {
		t.Fatalf("bad hex %q: %v", hex, err)
	}
	return math.Float64frombits(u)
}

func i64(t *testing.T, s string) int64 {
	t.Helper()
	v, err := strconv.ParseInt(s, 10, 64)
	if err != nil {
		t.Fatal(err)
	}
	return v
}

func u64(t *testing.T, s string) uint64 {
	t.Helper()
	v, err := strconv.ParseUint(s, 10, 64)
	if err != nil {
		t.Fatal(err)
	}
	return v
}

func exact(t *testing.T, name string, got float64, hex string) {
	t.Helper()
	if want := bits(t, hex); math.Float64bits(got) != math.Float64bits(want) {
		t.Errorf("%s = %v (%016x), want %v (%s)", name, got, math.Float64bits(got), want, hex)
	}
}

func point(t *testing.T, name string, got geometry.Correlithm, want []string) {
	t.Helper()
	if got.Dimensions() != len(want) {
		t.Errorf("%s: %d dimensions, want %d", name, got.Dimensions(), len(want))
		return
	}
	for i, hex := range want {
		if w := bits(t, hex); math.Float64bits(got.At(i)) != math.Float64bits(w) {
			t.Errorf("%s[%d] = %016x, want %s", name, i, math.Float64bits(got.At(i)), hex)
			return
		}
	}
}

func approx(t *testing.T, name string, got, want float64) {
	t.Helper()
	if got == want {
		return
	}
	if diff := math.Abs(got - want); diff > 1e-300 && diff > 1e-12*math.Abs(want) {
		t.Errorf("%s = %v, want %v (relative error %g)", name, got, want, diff/math.Abs(want))
	}
}

// ok unwraps a result that must not fail; a panic fails the test that called it.
func ok[T any](v T, err error) T {
	if err != nil {
		panic(err)
	}
	return v
}

func TestConformancePrng(t *testing.T) {
	for _, c := range load(t).Prng {
		seed := i64(t, c.Seed)
		u, d := seeding.New(seed), seeding.New(seed)
		for i, want := range c.Uint64 {
			if got := u.NextUint64(); got != u64(t, want) {
				t.Errorf("seed %s uint64[%d] = %d, want %s", c.Seed, i, got, want)
			}
		}
		for i, want := range c.Doubles {
			exact(t, "seed "+c.Seed+" double["+strconv.Itoa(i)+"]", d.NextDouble(), want)
		}
		for _, nc := range c.Next {
			p := seeding.New(seed)
			for i, want := range nc.Values {
				if got := ok(p.Next(nc.Max)); got != want {
					t.Errorf("seed %s Next(%d)[%d] = %d, want %d", c.Seed, nc.Max, i, got, want)
				}
			}
		}
	}
}

func TestConformanceDerive(t *testing.T) {
	for _, c := range load(t).Derive {
		child := seeding.New(i64(t, c.Seed)).Derive(c.Label)
		if child.Seed() != i64(t, c.ChildSeed) {
			t.Errorf("Derive(%s, %q) seed = %d, want %s", c.Seed, c.Label, child.Seed(), c.ChildSeed)
		}
		if got := child.NextUint64(); got != u64(t, c.FirstUint64) {
			t.Errorf("Derive(%s, %q) first = %d, want %s", c.Seed, c.Label, got, c.FirstUint64)
		}
		if got := child.Derive("x").Seed(); got != i64(t, c.GrandchildSeed) {
			t.Errorf("Derive(%s, %q).Derive(x) = %d, want %s", c.Seed, c.Label, got, c.GrandchildSeed)
		}
	}
}

func TestConformanceNCube(t *testing.T) {
	v := load(t).NCube
	if v.StandardDeviation != geometry.StandardDeviation || v.RadiusDeviation != geometry.RadiusDeviation || v.DiameterDeviation != geometry.DiameterDeviation {
		t.Errorf("constants differ: %v %v %v", v.StandardDeviation, v.RadiusDeviation, v.DiameterDeviation)
	}
	for _, c := range v.Cases {
		n := c.N
		name := "N=" + strconv.Itoa(n) + " "
		approx(t, name+"standardDistance", geometry.StandardDistance(n), c.StandardDistance)
		approx(t, name+"standardRadius", geometry.StandardRadius(n), c.StandardRadius)
		approx(t, name+"standardDiameter", geometry.StandardDiameter(n), c.StandardDiameter)
		approx(t, name+"cornerDistance", geometry.CornerDistance(n), c.CornerDistance)
		approx(t, name+"halfDiagonal", geometry.HalfDiagonal(n), c.HalfDiagonal)
		approx(t, name+"majorDiagonal", geometry.MajorDiagonal(n), c.MajorDiagonal)
		for _, d := range c.Distances {
			approx(t, name+"deviationsBelow", geometry.DeviationsBelow(n, d.Distance), d.DeviationsBelow)
			approx(t, name+"bitContent", geometry.BitContent(n, d.Distance), d.BitContent)
			approx(t, name+"probabilityOfProximity", geometry.ProbabilityOfProximity(n, d.Distance), d.ProbabilityOfProximity)
			approx(t, name+"pointCapacity", geometry.PointCapacity(n, d.Distance), d.PointCapacity)
		}
		for _, b := range c.BitsToDistance {
			approx(t, name+"distanceForBits", ok(geometry.DistanceForBits(n, b.Bits)), b.DistanceForBits)
		}
		for _, d := range c.DistanceAtDeviations {
			approx(t, name+"distanceAtDeviations", geometry.DistanceAtDeviations(n, d.Deviations), d.Distance)
		}
	}
}

func TestConformanceCorrelithm(t *testing.T) {
	v := load(t).Correlithm
	prng := seeding.New(i64(t, v.Seed))
	a := geometry.Random(prng, v.Dimensions)
	b := geometry.Random(prng, v.Dimensions)
	mid := geometry.Midpoint(v.Dimensions)
	point(t, "a", a, v.A)
	point(t, "b", b, v.B)
	point(t, "midpoint", mid, v.Midpoint)
	exact(t, "squaredDistance", a.SquaredDistanceTo(b), v.SquaredDistance)
	exact(t, "distance", a.DistanceTo(b), v.Distance)
	point(t, "centroid", ok(geometry.Centroid([]geometry.Correlithm{a, b, mid})), v.CentroidOfABMidpoint)
	for _, c := range v.Interpolate {
		point(t, "interpolate "+strconv.FormatFloat(c.Fraction, 'g', -1, 64), ok(a.Interpolate(b, c.Fraction)), c.Point)
	}
}

func TestConformanceStrings(t *testing.T) {
	v := load(t).Strings
	n := v.Dimensions
	line := strco.Line(seeding.New(i64(t, v.Line.Seed)), n)
	ring := strco.Ring(seeding.New(i64(t, v.Ring.Seed)), n)
	plane := strco.Plane(seeding.New(i64(t, v.Plane.Seed)), n)
	for _, c := range v.Line.At {
		point(t, "line.At("+c.T+")", ok(line.At(bits(t, c.T))), c.Point)
	}
	for _, c := range append(slices.Clone(v.Line.AtIndex), v.Line.AtIndexSingle...) {
		point(t, "line.AtIndex", ok(line.AtIndex(c.Index, c.Count)), c.Point)
	}
	for _, c := range v.Ring.At {
		point(t, "ring.At("+c.T+")", ok(ring.At(bits(t, c.T))), c.Point)
	}
	for _, c := range v.Ring.AtIndex {
		point(t, "ring.AtIndex", ok(ring.AtIndex(c.Index, c.Count)), c.Point)
	}
	for _, c := range v.Plane.At {
		point(t, "plane.AtXY("+c.X+", "+c.Y+")", ok(plane.AtXY(bits(t, c.X), bits(t, c.Y))), c.Point)
	}
}

func TestConformanceConverters(t *testing.T) {
	v := load(t).Converters
	n := v.Dimensions
	point(t, "missing", geometry.Midpoint(n), v.Missing)

	cardinal := converters.NewCardinal[string](seeding.New(i64(t, v.Cardinal.Seed)), n, nil)
	for _, c := range v.Cardinal.Cases {
		value := c.Value
		point(t, "cardinal "+strconv.Quote(value), ok(cardinal.Convert(&value)), c.Point)
	}

	ordinal := ok(converters.NewOrdinal(seeding.New(i64(t, v.Ordinal.Seed)), n, v.Ordinal.Order))
	for _, c := range v.Ordinal.Cases {
		value := c.Value
		point(t, "ordinal "+value, ok(ordinal.Convert(&value)), c.Point)
	}

	for name, cc := range map[string]continuousCase{"continuousLine": v.ContinuousLine, "continuousRing": v.ContinuousRing} {
		conv := ok(converters.NewContinuous(seeding.New(i64(t, cc.Seed)), n, cc.Min, cc.Max, cc.Wraps))
		for _, c := range cc.Cases {
			value := bits(t, c.Value)
			point(t, name+"("+c.Value+")", ok(conv.Convert(&value)), c.Point)
		}
	}

	pc := v.Planar
	planar := ok(converters.NewPlanar(seeding.New(i64(t, pc.Seed)), n, pc.MinX, pc.MaxX, pc.MinY, pc.MaxY))
	for _, c := range pc.Cases {
		xy := converters.XY{X: bits(t, c.X), Y: bits(t, c.Y)}
		point(t, "planar("+c.X+", "+c.Y+")", ok(planar.Convert(&xy)), c.Point)
	}
}

func TestConformanceMining(t *testing.T) {
	v := load(t).Mining
	plyPoints := map[string][]mining.PlyPoint[int]{}
	plies := map[string]map[int]geometry.Correlithm{}
	for name, pts := range v.Plies {
		plies[name] = map[int]geometry.Correlithm{}
		for _, p := range pts {
			coords := make([]float64, len(p.Point))
			for i, h := range p.Point {
				coords[i] = bits(t, h)
			}
			co := ok(geometry.NewCorrelithm(coords))
			plyPoints[name] = append(plyPoints[name], mining.PlyPoint[int]{ID: p.ID, Point: co})
			plies[name][p.ID] = co
		}
	}

	miner := ok(mining.NewPatternMiner(v.PatternMiner.MinDeviations, v.PatternMiner.MinMembers))
	mined := map[string][]*mining.Pattern[int]{}
	for _, ply := range []string{"faction", "turf"} {
		got := mining.Mine(miner, plyPoints[ply])
		mined[ply] = got
		want := v.Patterns[ply]
		if len(got) != len(want) {
			t.Fatalf("%s: %d patterns, want %d", ply, len(got), len(want))
		}
		for i, w := range want {
			name := ply + " pattern " + strconv.Itoa(i)
			if !slices.Equal(got[i].Members(), w.Members) {
				t.Errorf("%s members %v, want %v", name, got[i].Members(), w.Members)
			}
			point(t, name+" centroid", got[i].Centroid(), w.Centroid)
			exact(t, name+" radius", got[i].Radius(), w.Radius)
			exact(t, name+" meanPairDistance", got[i].MeanPairDistance(), w.MeanPairDistance)
			approx(t, name+" bits", got[i].Bits(), w.Bits)
		}
	}

	rules := ok(mining.MineRules(ok(mining.NewRuleMiner(v.RuleMiner.MinSupport)), "faction", mined["faction"], "turf", mined["turf"]))
	if len(rules) != len(v.Rules) {
		t.Fatalf("%d rules, want %d", len(rules), len(v.Rules))
	}
	for i, w := range v.Rules {
		r := rules[i]
		if r.SourcePly != w.SourcePly || r.TargetPly != w.TargetPly ||
			slices.Index(mined[w.SourcePly], r.Source) != w.SourcePattern || slices.Index(mined[w.TargetPly], r.Target) != w.TargetPattern {
			t.Errorf("rule %d = %s, want %s[%d] >: %s[%d]", i, r, w.SourcePly, w.SourcePattern, w.TargetPly, w.TargetPattern)
		}
		approx(t, "rule support", r.Support, w.Support)
		approx(t, "rule bits", r.Bits, w.Bits)
	}

	hits := ok(mining.Find(ok(mining.NewCue(v.Cue.TargetDeviations)), rules, plies))
	if len(hits) != len(v.Hits) {
		t.Fatalf("%d hits, want %d", len(hits), len(v.Hits))
	}
	for i, w := range v.Hits {
		h := hits[i]
		if h.ID != w.ID || h.Rank != w.Rank || slices.Index(rules, h.Rule) != w.Rule {
			t.Errorf("hit %d = id %d rank %d rule %d, want id %d rank %d rule %d", i, h.ID, h.Rank, slices.Index(rules, h.Rule), w.ID, w.Rank, w.Rule)
		}
		exact(t, "hit sourceDistance", h.SourceDistance, w.SourceDistance)
		exact(t, "hit targetDistance", h.TargetDistance, w.TargetDistance)
		approx(t, "hit bits", h.Bits, w.Bits)
	}
}

func TestConformanceBench(t *testing.T) {
	v := load(t).Bench
	pairs := make([]bench.Pair[int], len(v.Pairs))
	for i, p := range v.Pairs {
		pairs[i] = bench.Pair[int]{A: p[0], B: p[1]}
	}
	for _, c := range v.HoldoutRecall {
		table := v.Predictors[c.Predictor]
		got := ok(bench.HoldoutRecall(pairs, c.HoldoutFraction, i64(t, c.Seed), func(id int) []int { return table[strconv.Itoa(id)] }))
		want := bench.RecallResult{Hidden: c.Result.Hidden, Recovered: c.Result.Recovered, Predicted: c.Result.Predicted, PredictedTrue: c.Result.PredictedTrue}
		if got != want {
			t.Errorf("holdoutRecall %s %v seed %s = %+v, want %+v", c.Predictor, c.HoldoutFraction, c.Seed, got, want)
		}
	}

	var ids []int
	for k := range v.Reach.Adjacency {
		ids = append(ids, ok(strconv.Atoi(k)))
	}
	sort.Ints(ids)
	reach := ok(bench.Reach(ids, func(id int) []int { return v.Reach.Adjacency[strconv.Itoa(id)] }, v.Reach.MaxHops))
	if reach.Isolated != v.Reach.Isolated || reach.Total != v.Reach.Total || len(reach.MeanReachableByHop) != len(v.Reach.MeanReachableByHop) {
		t.Fatalf("reach = %+v, want %+v", reach, v.Reach)
	}
	for i, w := range v.Reach.MeanReachableByHop {
		approx(t, "meanReachableByHop", reach.MeanReachableByHop[i], w)
	}

	for _, c := range v.CascadeYield {
		approx(t, "cascadeYield", bench.CascadeYield(c.ClosedByCascade, c.DirectFixes), c.Yield)
	}
}
