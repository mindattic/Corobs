package strco

import (
	"errors"
	"math"
	"testing"

	corobs "github.com/mindattic/Corobs/Corobs.Go"
	"github.com/mindattic/Corobs/Corobs.Go/geometry"
	"github.com/mindattic/Corobs/Corobs.Go/seeding"
)

// Ch. VII: distance along the geometry becomes distance in the cube; strangers stay at mu.
const n = 2048 // large so a single string's statistics are tight

func at(t *testing.T, s *StringCo, pos float64) geometry.Correlithm {
	t.Helper()
	p, err := s.At(pos)
	if err != nil {
		t.Fatal(err)
	}
	return p
}

func atXY(t *testing.T, s *StringCo, x, y float64) geometry.Correlithm {
	t.Helper()
	p, err := s.AtXY(x, y)
	if err != nil {
		t.Fatal(err)
	}
	return p
}

func atIndex(t *testing.T, s *StringCo, i, count int) geometry.Correlithm {
	t.Helper()
	p, err := s.AtIndex(i, count)
	if err != nil {
		t.Fatal(err)
	}
	return p
}

func within(t *testing.T, name string, got, want, tol float64) {
	t.Helper()
	if math.Abs(got-want) > tol {
		t.Fatalf("%s = %v, want %v +/- %v", name, got, want, tol)
	}
}

func TestLineDistanceGrowsAsRootOfSeparationAndReachesMu(t *testing.T) {
	line := Line(seeding.New(11), n)
	mu := geometry.StandardDistance(n)
	origin := at(t, line, 0)
	d1 := origin.DistanceTo(at(t, line, 0.1))
	d3 := origin.DistanceTo(at(t, line, 0.3))
	d6 := origin.DistanceTo(at(t, line, 0.6))
	d10 := origin.DistanceTo(at(t, line, 1.0))
	if !(d1 < d3 && d3 < d6 && d6 < d10) {
		t.Fatalf("distances not increasing: %v %v %v %v", d1, d3, d6, d10)
	}
	within(t, "d(0.1)/mu ~ sqrt|dt|", d1/mu, math.Sqrt(0.1), 0.06)
	within(t, "the far ends are at standard distance", d10/mu, 1, 0.06)
	if origin.DistanceTo(origin) != 0 {
		t.Fatal("self distance")
	}
}

func TestRingWraps(t *testing.T) {
	ring := Ring(seeding.New(12), n)
	mu := geometry.StandardDistance(n)
	origin := at(t, ring, 0)
	within(t, "opposite side is mu", origin.DistanceTo(at(t, ring, 0.5))/mu, 1, 0.06)
	if !(origin.DistanceTo(at(t, ring, 0.98)) < origin.DistanceTo(at(t, ring, 0.25))) {
		t.Fatal("0.98 is next to 0")
	}
	if at(t, ring, 0.3).DistanceTo(at(t, ring, 1.3)) != 0 {
		t.Fatal("t is taken mod 1")
	}
}

func TestPlaneIsIsotropic(t *testing.T) {
	plane := Plane(seeding.New(13), n)
	origin := atXY(t, plane, 0.5, 0.5)
	alongX := origin.DistanceTo(atXY(t, plane, 0.8, 0.5))
	alongY := origin.DistanceTo(atXY(t, plane, 0.5, 0.8))
	diag := 0.5 + 0.3/math.Sqrt(2)
	diagonal := origin.DistanceTo(atXY(t, plane, diag, diag))
	within(t, "along x vs along y", alongX, alongY, alongY*0.15)
	within(t, "diagonal vs along x", diagonal, alongX, alongX*0.2)
	if !(origin.DistanceTo(atXY(t, plane, 0.55, 0.5)) < alongX) {
		t.Fatal("a nearer position must be nearer")
	}
}

func TestEveryPositionIsAStrangerToAnUnrelatedPoint(t *testing.T) {
	prng := seeding.New(14)
	line := Line(prng, n)
	stranger := geometry.Random(prng, n)
	mu := geometry.StandardDistance(n)
	for _, pos := range []float64{0, 0.25, 0.5, 0.75, 1} {
		within(t, "stranger distance / mu", at(t, line, pos).DistanceTo(stranger)/mu, 1, 0.06)
	}
}

func TestOrdinalPositionsAreEvenlySpaced(t *testing.T) {
	line := Line(seeding.New(15), n)
	a, b, e, z := atIndex(t, line, 0, 26), atIndex(t, line, 1, 26), atIndex(t, line, 4, 26), atIndex(t, line, 25, 26)
	if !(a.DistanceTo(b) < a.DistanceTo(e) && a.DistanceTo(e) < a.DistanceTo(z)) {
		t.Fatal("ordinal spacing")
	}
}

func TestSameSeedSameString(t *testing.T) {
	a := atXY(t, Plane(seeding.New(16), 64), 0.2, 0.7)
	b := atXY(t, Plane(seeding.New(16), 64), 0.2, 0.7)
	if !a.Equal(b) {
		t.Fatal("same seed, different string")
	}
}

func TestWrongShapeAndNaNAreRefused(t *testing.T) {
	line := Line(seeding.New(1), 8)
	plane := Plane(seeding.New(2), 8)
	cases := []struct {
		name string
		err  error
		want error
	}{
		{"plane.At", second(plane.At(0.5)), corobs.ErrInvalidOperation},
		{"line.AtXY", second(line.AtXY(0.5, 0.5)), corobs.ErrInvalidOperation},
		{"line.At(NaN)", second(line.At(math.NaN())), corobs.ErrOutOfRange},
		{"plane.AtXY(NaN)", second(plane.AtXY(0.5, math.NaN())), corobs.ErrOutOfRange},
		{"AtIndex count 0", second(line.AtIndex(0, 0)), corobs.ErrOutOfRange},
		{"AtIndex index past count", second(line.AtIndex(3, 3)), corobs.ErrOutOfRange},
	}
	for _, c := range cases {
		if !errors.Is(c.err, c.want) {
			t.Fatalf("%s: error %v, want %v", c.name, c.err, c.want)
		}
	}
	if p := atIndex(t, line, 0, 1); !p.Equal(at(t, line, 0)) {
		t.Fatal("a single ordinal value sits at the start")
	}
	if !at(t, line, -3).Equal(at(t, line, 0)) || !at(t, line, math.Inf(1)).Equal(at(t, line, 1)) {
		t.Fatal("a line clamps t to [0, 1]")
	}
}

func second(_ geometry.Correlithm, err error) error { return err }
