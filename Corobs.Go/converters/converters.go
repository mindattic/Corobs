// Package converters moves world data into CO space (a sensor, Ch. IX): cardinal sets become random
// tokens, ordinal sets evenly spaced positions on a line string CO, continuous values positions on a
// line or ring, and map positions points on a planar string CO. Every converter answers the same
// question for a missing value (a nil pointer): the cube's midpoint, which carries no bits.
package converters

import (
	"fmt"
	"math"

	corobs "github.com/mindattic/Corobs/Corobs.Go"
	"github.com/mindattic/Corobs/Corobs.Go/geometry"
	"github.com/mindattic/Corobs/Corobs.Go/seeding"
	"github.com/mindattic/Corobs/Corobs.Go/strco"
)

// Converter is a sensor for values of type T. A nil value is missing and converts to Missing.
type Converter[T any] interface {
	// Dimensions is N, the dimensionality of the points this converter produces.
	Dimensions() int
	// Convert gives the point for *value, or Missing for nil.
	Convert(value *T) (geometry.Correlithm, error)
	// Missing is where an absent value lands: the midpoint.
	Missing() geometry.Correlithm
}

// Cardinal converts a cardinal set, values with no order (a faction, a species, a type): each
// distinct value gets its own random CO, derived from the seed and the value's key, so the mapping
// is the same on every build regardless of the order values were first seen.
type Cardinal[T any] struct {
	root       *seeding.SeededPrng
	key        func(T) string
	cache      map[string]geometry.Correlithm
	dimensions int
	missing    geometry.Correlithm
}

// NewCardinal returns a cardinal converter over dimensions-dimensional points, each value's random
// CO derived from root and the value's key (key, or fmt.Sprint when nil, the counterpart of C#
// ToString) so the mapping does not depend on arrival order. Panics for dimensions <= 0.
func NewCardinal[T any](root *seeding.SeededPrng, dimensions int, key func(T) string) *Cardinal[T] {
	if key == nil {
		key = func(v T) string { return fmt.Sprint(v) }
	}
	return &Cardinal[T]{root: root, key: key, cache: map[string]geometry.Correlithm{}, dimensions: dimensions, missing: geometry.Midpoint(dimensions)}
}

// Dimensions is N.
func (c *Cardinal[T]) Dimensions() int { return c.dimensions }

// Missing is the midpoint.
func (c *Cardinal[T]) Missing() geometry.Correlithm { return c.missing }

// Convert gives the value's CO (created and cached on first use), or Missing for nil. It never fails.
func (c *Cardinal[T]) Convert(value *T) (geometry.Correlithm, error) {
	if value == nil {
		return c.missing, nil
	}
	k := c.key(*value)
	co, ok := c.cache[k]
	if !ok {
		co = geometry.Random(c.root.Derive(k), c.dimensions)
		c.cache[k] = co
	}
	return co, nil
}

// Ordinal converts an ordinal set, values with an order but no scale (tiers, ranks, an alphabet):
// evenly spaced positions on a line string CO, so neighbours are near and the extremes are at
// standard distance (Fig. VII-8). An unknown value is an error, not a guess.
type Ordinal[T comparable] struct {
	index      map[T]int
	line       *strco.StringCo
	dimensions int
	missing    geometry.Correlithm
}

// NewOrdinal returns an ordinal converter whose order[0] is the first position and order[len-1]
// the last, evenly spaced along a fresh line string CO. order must be non-empty and free of
// duplicates. Panics for dimensions <= 0.
func NewOrdinal[T comparable](prng *seeding.SeededPrng, dimensions int, order []T) (*Ordinal[T], error) {
	if len(order) == 0 {
		return nil, fmt.Errorf("%w: an ordinal set needs at least one value", corobs.ErrArgument)
	}
	index := make(map[T]int, len(order))
	for i, v := range order {
		if _, dup := index[v]; dup {
			return nil, fmt.Errorf("%w: '%v' appears twice in the order", corobs.ErrArgument, v)
		}
		index[v] = i
	}
	line := strco.Line(prng, dimensions)
	return &Ordinal[T]{index: index, line: line, dimensions: dimensions, missing: geometry.Midpoint(dimensions)}, nil
}

// Dimensions is N.
func (c *Ordinal[T]) Dimensions() int { return c.dimensions }

// Missing is the midpoint.
func (c *Ordinal[T]) Missing() geometry.Correlithm { return c.missing }

// Count is how many distinct values are in the order.
func (c *Ordinal[T]) Count() int { return len(c.index) }

// Convert gives the value's position on the line (Missing for nil); a value outside the ordered
// set is an error, since there is no sensible place to guess it belongs.
func (c *Ordinal[T]) Convert(value *T) (geometry.Correlithm, error) {
	if value == nil {
		return c.missing, nil
	}
	i, ok := c.index[*value]
	if !ok {
		return geometry.Correlithm{}, fmt.Errorf("%w: '%v' is not in this ordinal set", corobs.ErrArgument, *value)
	}
	return c.line.AtIndex(i, len(c.index))
}

// Continuous converts a continuous variable on [min, max] (an age, a date, a price) onto a line
// string CO, or onto a ring when the range wraps (hours of the day, compass bearings).
type Continuous struct {
	str        *strco.StringCo
	min, max   float64
	wraps      bool
	dimensions int
	missing    geometry.Correlithm
}

// NewContinuous returns a continuous converter over [min, max] on a fresh string CO: a line, or a
// ring when wraps (the range's two ends are the same position). max must exceed min. Panics for
// dimensions <= 0.
func NewContinuous(prng *seeding.SeededPrng, dimensions int, min, max float64, wraps bool) (*Continuous, error) {
	if !(max > min) {
		return nil, fmt.Errorf("%w: max must exceed min", corobs.ErrArgument)
	}
	var s *strco.StringCo
	if wraps {
		s = strco.Ring(prng, dimensions)
	} else {
		s = strco.Line(prng, dimensions)
	}
	return &Continuous{str: s, min: min, max: max, wraps: wraps, dimensions: dimensions, missing: geometry.Midpoint(dimensions)}, nil
}

// Dimensions is N.
func (c *Continuous) Dimensions() int { return c.dimensions }

// Missing is the midpoint.
func (c *Continuous) Missing() geometry.Correlithm { return c.missing }

// Convert gives the value's point on the string: Missing for nil, NaN, or an infinite value on a
// ring, which has no phase to land on.
func (c *Continuous) Convert(value *float64) (geometry.Correlithm, error) {
	if value == nil || math.IsNaN(*value) {
		return c.missing, nil
	}
	// COR-T5 (docs/BUGS.md, a decision, not a proven error): a ring has no phase for infinity.
	if c.wraps && math.IsInf(*value, 0) {
		return c.missing, nil
	}
	t := (*value - c.min) / (c.max - c.min)
	return c.str.At(t)
}

// XY is a position in a plane.
type XY struct{ X, Y float64 }

// Planar converts a point in a bounded plane, a map position, onto a planar string CO (Fig. VII-10).
type Planar struct {
	plane                  *strco.StringCo
	minX, maxX, minY, maxY float64
	dimensions             int
	missing                geometry.Correlithm
}

// NewPlanar returns a planar converter over the rectangle [minX, maxX] x [minY, maxY] on a fresh
// planar string CO. Each axis needs max > min. Panics for dimensions <= 0.
func NewPlanar(prng *seeding.SeededPrng, dimensions int, minX, maxX, minY, maxY float64) (*Planar, error) {
	if !(maxX > minX) || !(maxY > minY) {
		return nil, fmt.Errorf("%w: each axis needs max > min", corobs.ErrArgument)
	}
	return &Planar{plane: strco.Plane(prng, dimensions), minX: minX, maxX: maxX, minY: minY, maxY: maxY, dimensions: dimensions, missing: geometry.Midpoint(dimensions)}, nil
}

// Dimensions is N.
func (c *Planar) Dimensions() int { return c.dimensions }

// Missing is the midpoint.
func (c *Planar) Missing() geometry.Correlithm { return c.missing }

// Convert gives the value's point on the plane: Missing for nil or a NaN coordinate.
func (c *Planar) Convert(value *XY) (geometry.Correlithm, error) {
	if value == nil || math.IsNaN(value.X) || math.IsNaN(value.Y) {
		return c.missing, nil
	}
	return c.plane.AtXY((value.X-c.minX)/(c.maxX-c.minX), (value.Y-c.minY)/(c.maxY-c.minY))
}

var (
	_ Converter[string]  = (*Cardinal[string])(nil)
	_ Converter[string]  = (*Ordinal[string])(nil)
	_ Converter[float64] = (*Continuous)(nil)
	_ Converter[XY]      = (*Planar)(nil)
)
