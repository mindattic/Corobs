package geometry

import (
	"errors"
	"math"
	"testing"

	corobs "github.com/mindattic/Corobs/Corobs.Go"
	"github.com/mindattic/Corobs/Corobs.Go/seeding"
)

func within(t *testing.T, name string, got, want, tol float64) {
	t.Helper()
	if math.Abs(got-want) > tol {
		t.Fatalf("%s = %v, want %v +/- %v", name, got, want, tol)
	}
}

func mean(xs []float64) float64 {
	s := 0.0
	for _, x := range xs {
		s += x
	}
	return s / float64(len(xs))
}

// Table II-1 and Ch. III, checked against the cube itself.
func TestRandomPointsSitAtStandardDistanceWithTheBooksDeviation(t *testing.T) {
	for _, n := range []int{64, 100} {
		prng := seeding.New(2004)
		distances := make([]float64, 3000)
		for i := range distances {
			a := Random(prng, n)
			distances[i] = a.DistanceTo(Random(prng, n))
		}
		m := mean(distances)
		ss := 0.0
		for _, d := range distances {
			ss += (d - m) * (d - m)
		}
		sd := math.Sqrt(ss / float64(len(distances)-1))
		within(t, "mean (mu = sqrt(N/6))", m, StandardDistance(n), 0.03)
		within(t, "sd (sigma = sqrt(7/120), independent of N)", sd, StandardDeviation, 0.025)
	}
}

func TestMidpointAndCornerDistancesMatchTheTable(t *testing.T) {
	for _, n := range []int{64, 100} {
		prng := seeding.New(7)
		mid := Midpoint(n)
		corner, err := NewCorrelithm(make([]float64, n))
		if err != nil {
			t.Fatal(err)
		}
		toMid := make([]float64, 2000)
		toCorner := make([]float64, 2000)
		for i := range toMid {
			p := Random(prng, n)
			toMid[i] = p.DistanceTo(mid)
			toCorner[i] = p.DistanceTo(corner)
		}
		within(t, "standard radius sqrt(N/12)", mean(toMid), StandardRadius(n), 0.02)
		within(t, "standard diameter sqrt(N/3)", mean(toCorner), StandardDiameter(n), 0.03)
		within(t, "half diagonal", HalfDiagonal(n), mid.DistanceTo(corner), 1e-12)
	}
}

func TestBitContentFollowsEquationIIIH(t *testing.T) {
	const n = 100
	mu := StandardDistance(n)
	if BitContent(n, mu) != 0 {
		t.Fatal("bits at mu must be 0")
	}
	if BitContent(n, mu+1) != 0 {
		t.Fatal("beyond mu carries nothing")
	}
	// 24.75*(mu-d)^2 is the book's rounded form of ((mu-d)/sigma)^2/ln 2.
	within(t, "bits at mu-1", BitContent(n, mu-1), 24.75, 0.1)
	// Rule of thumb: a little over four bits per dimension at d = 0.
	within(t, "bits per dimension at 0", BitContent(n, 0)/n, 4.12, 0.02)
	d, err := DistanceForBits(n, 24.75)
	if err != nil {
		t.Fatal(err)
	}
	within(t, "DistanceForBits(24.75)", d, mu-1, 0.005)
	if _, err := DistanceForBits(n, -1); !errors.Is(err, corobs.ErrOutOfRange) {
		t.Fatalf("negative bits error = %v", err)
	}
}

func TestProbabilityOfProximityIsTwoToTheMinusBits(t *testing.T) {
	const n = 100
	mu := StandardDistance(n)
	if ProbabilityOfProximity(n, mu) != 1 {
		t.Fatal("probability at mu must be 1")
	}
	// Eq. III-J: 10^(-7.45(mu-d)^2); at mu-d = 0.5 -> 10^-1.86.
	within(t, "log10 P at mu-0.5", math.Log10(ProbabilityOfProximity(n, mu-0.5)), -1.86, 0.02)
}

func TestPointCapacityFollowsEquationIIIQ(t *testing.T) {
	// Book: N=96, d=1.0 -> about 10^33 points before a pair falls within 1.0 of each other.
	within(t, "log10 capacity", math.Log10(PointCapacity(96, 1.0)), 33.3, 0.3)
	if PointCapacity(96, StandardDistance(96)) != 1 {
		t.Fatal("capacity at mu must be 1")
	}
}

func TestDeviationsAndDistancesRoundTrip(t *testing.T) {
	const n = 64
	d := DistanceAtDeviations(n, 6)
	within(t, "deviations", DeviationsBelow(n, d), 6, 1e-9)
	within(t, "6 sigma ~ 52 bits", BitContent(n, d), 36/math.Log(2), 1e-9)
}

func TestNonPositiveDimensionsPanic(t *testing.T) {
	for name, f := range map[string]func(){
		"StandardDistance": func() { StandardDistance(0) },
		"Random":           func() { Random(seeding.New(1), 0) },
		"Midpoint":         func() { Midpoint(-1) },
	} {
		func() {
			defer func() {
				err, _ := recover().(error)
				if !errors.Is(err, corobs.ErrOutOfRange) {
					t.Fatalf("%s: recovered %v, want ErrOutOfRange", name, err)
				}
			}()
			f()
		}()
	}
}

func TestCorrelithmValidatesAndCopiesItsCoordinates(t *testing.T) {
	if _, err := NewCorrelithm(nil); !errors.Is(err, corobs.ErrArgument) {
		t.Fatalf("empty: %v", err)
	}
	for _, bad := range [][]float64{{0.5, -0.1}, {1.1}, {math.NaN()}} {
		if _, err := NewCorrelithm(bad); !errors.Is(err, corobs.ErrOutOfRange) {
			t.Fatalf("%v: %v", bad, err)
		}
	}
	c := []float64{0, 0.25, 1}
	p, err := NewCorrelithm(c)
	if err != nil {
		t.Fatal(err)
	}
	c[0] = 0.9
	if p.At(0) != 0 || p.Dimensions() != 3 || p.String() != "CO[3]" {
		t.Fatal("the point must own a copy of its coordinates")
	}
	out := p.Coordinates()
	out[1] = 0.9
	if p.At(1) != 0.25 {
		t.Fatal("Coordinates must return a copy")
	}
}

func TestCorrelithmOperations(t *testing.T) {
	a, _ := NewCorrelithm([]float64{0, 0, 0})
	b, _ := NewCorrelithm([]float64{1, 1, 1})
	if a.SquaredDistanceTo(b) != 3 || a.DistanceTo(b) != math.Sqrt(3) {
		t.Fatal("distance")
	}
	mid, err := a.Interpolate(b, 0.5)
	if err != nil || !mid.Equal(Midpoint(3)) {
		t.Fatalf("interpolate: %v %v", mid, err)
	}
	if _, err := a.Interpolate(b, 1.5); !errors.Is(err, corobs.ErrOutOfRange) {
		t.Fatalf("fraction out of range: %v", err)
	}
	c, err := Centroid([]Correlithm{a, b})
	if err != nil || !c.Equal(Midpoint(3)) {
		t.Fatalf("centroid: %v %v", c, err)
	}
	if s, err := Superpose([]Correlithm{a, b}); err != nil || !s.Equal(c) {
		t.Fatal("superpose is the centroid")
	}
	if _, err := Centroid(nil); !errors.Is(err, corobs.ErrArgument) {
		t.Fatalf("empty centroid: %v", err)
	}
	if _, err := Centroid([]Correlithm{a, Midpoint(2)}); !errors.Is(err, corobs.ErrArgument) {
		t.Fatalf("mixed centroid: %v", err)
	}
	if a.Equal(b) || a.Equal(Midpoint(2)) {
		t.Fatal("equality")
	}
	defer func() {
		if err, _ := recover().(error); !errors.Is(err, corobs.ErrArgument) {
			t.Fatalf("mixed distance recovered %v", err)
		}
	}()
	a.DistanceTo(Midpoint(2))
}
