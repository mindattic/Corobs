package geometry

import (
	"fmt"
	"math"

	corobs "github.com/mindattic/Corobs/Corobs.Go"
	"github.com/mindattic/Corobs/Corobs.Go/seeding"
)

// Correlithm is a correlithm object: one point in the real unit N-cube, every coordinate in [0, 1].
// A CO is a soft token (Ch. IV): it stands for its datum exactly at its coordinates and, to a
// degree BitContent quantifies, at every point nearby. Immutable; the zero value is not a point.
type Correlithm struct {
	c []float64
}

// NewCorrelithm returns a point at exactly these coordinates (copied); each must lie in [0, 1].
func NewCorrelithm(coordinates []float64) (Correlithm, error) {
	if len(coordinates) == 0 {
		return Correlithm{}, fmt.Errorf("%w: a point needs at least one coordinate", corobs.ErrArgument)
	}
	for _, v := range coordinates {
		if math.IsNaN(v) || v < 0 || v > 1 {
			return Correlithm{}, fmt.Errorf("%w: every coordinate must lie in [0, 1]", corobs.ErrOutOfRange)
		}
	}
	return Correlithm{c: append([]float64(nil), coordinates...)}, nil
}

// Random returns a point chosen uniformly at random from the whole cube: a fresh token, at standard
// distance from every other random token with overwhelming probability. Panics for dimensions <= 0.
func Random(prng *seeding.SeededPrng, dimensions int) Correlithm {
	c := make([]float64, checkDimensions(dimensions))
	for i := range c {
		c[i] = prng.NextDouble()
	}
	return Correlithm{c: c}
}

// Midpoint is the cube's centre, 0.5 in every dimension: where a missing value goes, because the
// midpoint is at StandardRadius from everything and carries no bits. Panics for dimensions <= 0.
func Midpoint(dimensions int) Correlithm {
	c := make([]float64, checkDimensions(dimensions))
	for i := range c {
		c[i] = 0.5
	}
	return Correlithm{c: c}
}

// Dimensions is N, the dimensionality of the cube this point lives in.
func (p Correlithm) Dimensions() int { return len(p.c) }

// At is the coordinate on one dimension, in [0, 1].
func (p Correlithm) At(dimension int) float64 { return p.c[dimension] }

// Coordinates returns a copy of all N coordinates, in order.
func (p Correlithm) Coordinates() []float64 { return append([]float64(nil), p.c...) }

// SquaredDistanceTo is the Euclidean distance squared to other, from the same cube. Panics when
// other has a different dimensionality: points from different spaces have no distance.
func (p Correlithm) SquaredDistanceTo(other Correlithm) float64 {
	p.checkSame(other)
	s := 0.0
	for i, a := range p.c {
		d := a - other.c[i]
		s += float64(d * d)
	}
	return s
}

// DistanceTo is the Euclidean distance to other; compare against StandardDistance to read it as
// information (BitContent). Panics when other has a different dimensionality.
func (p Correlithm) DistanceTo(other Correlithm) float64 {
	return math.Sqrt(p.SquaredDistanceTo(other))
}

// Interpolate moves linearly by fraction from this point toward other. Note Ch. VII's warning:
// interpolated points "take a shortcut" and sit closer than standard distance to third points; use
// a string CO (package strco) for sequences.
func (p Correlithm) Interpolate(other Correlithm, fraction float64) (Correlithm, error) {
	p.checkSame(other)
	if fraction < 0 || fraction > 1 {
		return Correlithm{}, fmt.Errorf("%w: fraction must lie in [0, 1], got %v", corobs.ErrOutOfRange, fraction)
	}
	c := make([]float64, len(p.c))
	for i := range c {
		c[i] = p.c[i] + float64((other.c[i]-p.c[i])*fraction)
	}
	return Correlithm{c: c}, nil
}

// Centroid is the coordinate-wise mean of a set of points, summed in order.
func Centroid(points []Correlithm) (Correlithm, error) {
	if len(points) == 0 {
		return Correlithm{}, fmt.Errorf("%w: a centroid needs at least one point", corobs.ErrArgument)
	}
	var sum []float64
	for _, pt := range points {
		if sum == nil {
			sum = make([]float64, pt.Dimensions())
		}
		if len(sum) != pt.Dimensions() {
			return Correlithm{}, fmt.Errorf("%w: all points must share one dimensionality", corobs.ErrArgument)
		}
		for i := range sum {
			sum[i] += pt.c[i]
		}
	}
	count := float64(len(points))
	for i := range sum {
		sum[i] /= count
	}
	return Correlithm{c: sum}, nil
}

// Superpose returns a point that superposes several: their centroid. Each component remains
// recoverable, lying closer to the centroid than a random point would (Ch. VIII, Superposition).
func Superpose(points []Correlithm) (Correlithm, error) { return Centroid(points) }

// Equal reports whether every coordinate matches exactly; it is not a proximity test. Two
// independently drawn points are, by the book's statistics, never equal; use DistanceTo for that.
func (p Correlithm) Equal(other Correlithm) bool {
	if len(p.c) != len(other.c) {
		return false
	}
	for i, v := range p.c {
		if v != other.c[i] {
			return false
		}
	}
	return true
}

// String gives just the dimensionality; coordinates are not meant to be read as text.
func (p Correlithm) String() string { return fmt.Sprintf("CO[%d]", len(p.c)) }

func (p Correlithm) checkSame(other Correlithm) {
	if len(other.c) != len(p.c) {
		panic(fmt.Errorf("%w: points from different spaces have no distance", corobs.ErrArgument))
	}
}

func checkDimensions(dimensions int) int {
	if dimensions <= 0 {
		panic(fmt.Errorf("%w: dimensions must be positive, got %d", corobs.ErrOutOfRange, dimensions))
	}
	return dimensions
}
