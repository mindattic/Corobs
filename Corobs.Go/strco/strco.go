// Package strco holds string COs (Ch. VII): a lower-dimensional geometry (a line, a ring, a plane)
// embedded in the N-cube so that distance along the geometry is reflected as distance in the cube,
// rising from zero to standard distance as positions move apart, while every position stays at
// standard distance from any unrelated random point.
//
// The package is named strco, not strings, so that it never shadows the standard library's strings.
package strco

import (
	"fmt"
	"math"

	corobs "github.com/mindattic/Corobs/Corobs.Go"
	"github.com/mindattic/Corobs/Corobs.Go/geometry"
	"github.com/mindattic/Corobs/Corobs.Go/seeding"
)

type kind int

const (
	line kind = iota
	ring
	plane
)

// StringCo is a string CO. Construction follows the book's advice to "distribute the anomalies
// randomly": each dimension carries two random values and switches between them at its own random
// breakpoint along the geometry. Two positions then differ in exactly the dimensions whose
// breakpoint lies between them, so the expected squared distance is mu^2 times the fraction of such
// dimensions: sqrt|dt|*mu on a line, sqrt(2*delta)*mu around a ring (delta <= 1/2), and isotropic in
// the plane. No interpolation is involved, so no position "takes a shortcut" toward third points.
type StringCo struct {
	kind    kind
	a, b, o []float64
	dx, dy  []float64
}

// Line is a line segment parameterised by t in [0, 1]. Distance between t and t' ~ mu*sqrt|t - t'|.
// Panics for dimensions <= 0.
func Line(prng *seeding.SeededPrng, dimensions int) *StringCo {
	a, b := values(prng, dimensions)
	o := make([]float64, dimensions)
	for i := range o {
		o[i] = prng.NextDouble()
	}
	return &StringCo{kind: line, a: a, b: b, o: o}
}

// Ring is a closed ring parameterised by t in [0, 1) with 0 = 1, for hours, headings, seasons.
// Distance between t and t' ~ mu*sqrt(2*delta) where delta is the circular gap (<= 1/2). Panics
// for dimensions <= 0.
func Ring(prng *seeding.SeededPrng, dimensions int) *StringCo {
	a, b := values(prng, dimensions)
	o := make([]float64, dimensions)
	for i := range o {
		o[i] = prng.NextDouble()
	}
	return &StringCo{kind: ring, a: a, b: b, o: o}
}

// Plane is a unit square parameterised by (x, y) in [0, 1]^2. Each dimension watches a random
// direction, so distance grows with planar separation in every direction alike: the symmetric
// "cone" of Fig. VII-10, without the troughs of concatenated 1-D strings (Fig. VII-11). Panics for
// dimensions <= 0.
func Plane(prng *seeding.SeededPrng, dimensions int) *StringCo {
	a, b := values(prng, dimensions)
	o := make([]float64, dimensions)
	dx := make([]float64, dimensions)
	dy := make([]float64, dimensions)
	for i := range o {
		theta := prng.NextDouble() * 2 * math.Pi
		dx[i] = math.Cos(theta)
		dy[i] = math.Sin(theta)
		lo := math.Min(0, dx[i]) + math.Min(0, dy[i])
		hi := math.Max(0, dx[i]) + math.Max(0, dy[i])
		o[i] = lo + float64(prng.NextDouble()*(hi-lo))
	}
	return &StringCo{kind: plane, a: a, b: b, o: o, dx: dx, dy: dy}
}

// Dimensions is N, the dimensionality of the cube this geometry is embedded in.
func (s *StringCo) Dimensions() int { return len(s.a) }

// At is the point at position t on a line (clamped to [0, 1]) or a ring (taken mod 1). NaN is out
// of range, and so is an infinite t on a ring, which has no phase (COR-T4, docs/BUGS.md); a plane
// takes AtXY instead.
func (s *StringCo) At(t float64) (geometry.Correlithm, error) {
	if s.kind == plane {
		return geometry.Correlithm{}, fmt.Errorf("%w: a planar string CO takes two coordinates", corobs.ErrInvalidOperation)
	}
	if math.IsNaN(t) {
		return geometry.Correlithm{}, fmt.Errorf("%w: t is NaN", corobs.ErrOutOfRange)
	}
	c := make([]float64, s.Dimensions())
	if s.kind == line {
		t = clamp01(t)
		for i := range c {
			if t < s.o[i] {
				c[i] = s.a[i]
			} else {
				c[i] = s.b[i]
			}
		}
	} else {
		// COR-T4 (docs/BUGS.md): infinity has no phase; the old path returned a point off the ring.
		if math.IsInf(t, 0) {
			return geometry.Correlithm{}, fmt.Errorf("%w: a ring has no position at %v", corobs.ErrOutOfRange, t)
		}
		for i := range c {
			phase := t - s.o[i]
			phase -= math.Floor(phase)
			if phase < 0.5 {
				c[i] = s.a[i]
			} else {
				c[i] = s.b[i]
			}
		}
	}
	return point(c), nil
}

// AtXY is the point at (x, y) on a plane, each clamped to [0, 1].
func (s *StringCo) AtXY(x, y float64) (geometry.Correlithm, error) {
	if s.kind != plane {
		return geometry.Correlithm{}, fmt.Errorf("%w: only a planar string CO takes two coordinates", corobs.ErrInvalidOperation)
	}
	if math.IsNaN(x) || math.IsNaN(y) {
		return geometry.Correlithm{}, fmt.Errorf("%w: x or y is NaN", corobs.ErrOutOfRange)
	}
	x, y = clamp01(x), clamp01(y)
	c := make([]float64, s.Dimensions())
	for i := range c {
		p := float64(x*s.dx[i]) + float64(y*s.dy[i])
		if p < s.o[i] {
			c[i] = s.a[i]
		} else {
			c[i] = s.b[i]
		}
	}
	return point(c), nil
}

// AtIndex is the index-th of count evenly spaced positions: an ordinal set such as an alphabet, a
// rank or a tier (Fig. VII-8).
func (s *StringCo) AtIndex(index, count int) (geometry.Correlithm, error) {
	if count <= 0 {
		return geometry.Correlithm{}, fmt.Errorf("%w: count must be positive, got %d", corobs.ErrOutOfRange, count)
	}
	if index < 0 || index >= count {
		return geometry.Correlithm{}, fmt.Errorf("%w: index %d outside [0, %d)", corobs.ErrOutOfRange, index, count)
	}
	if s.kind == ring {
		return s.At(float64(index) / float64(count))
	}
	if count == 1 {
		return s.At(0)
	}
	return s.At(float64(index) / float64(count-1))
}

func values(prng *seeding.SeededPrng, dimensions int) ([]float64, []float64) {
	if dimensions <= 0 {
		panic(fmt.Errorf("%w: dimensions must be positive, got %d", corobs.ErrOutOfRange, dimensions))
	}
	a := make([]float64, dimensions)
	b := make([]float64, dimensions)
	for i := range a {
		a[i] = prng.NextDouble()
		b[i] = prng.NextDouble()
	}
	return a, b
}

// clamp01 matches .NET Math.Clamp(v, 0, 1) for non-NaN v.
func clamp01(v float64) float64 {
	if v < 0 {
		return 0
	}
	if v > 1 {
		return 1
	}
	return v
}

func point(c []float64) geometry.Correlithm {
	p, err := geometry.NewCorrelithm(c)
	if err != nil {
		panic(err) // unreachable: every coordinate is one of the stored values in [0, 1)
	}
	return p
}
