// Package geometry holds the statistics of the real unit N-cube (Ch. II-III) and Correlithm, a
// point in it.
package geometry

import (
	"fmt"
	"math"

	corobs "github.com/mindattic/Corobs/Corobs.Go"
)

// The statistics of the real unit N-cube (Lawrence, Correlithm Object Technology, Ch. II-III).
// Two points chosen at random are almost always StandardDistance apart, with a standard deviation
// that does not grow with N (Table II-1). Proximity far below that distance is therefore
// information: BitContent says how much (Eq. III-H), ProbabilityOfProximity how unlikely by chance
// (Eq. III-J), PointCapacity how many random points fit before two collide (Eq. III-Q). Valid for N
// of about 20 and up; 50-128 is the working range. Every function panics for dimensions <= 0.
const (
	// StandardDeviation is sigma of the distance between two random points: sqrt(7/120) ~ 0.2415, independent of N.
	StandardDeviation = 0.24152294576982397
	// RadiusDeviation is sigma of the distance from the midpoint to a random point: sqrt(1/60) ~ 0.1291.
	RadiusDeviation = 0.12909944487358055
	// DiameterDeviation is sigma of the distance from a corner to a random point: sqrt(1/15) ~ 0.2582.
	DiameterDeviation = 0.2581988897471611
)

// StandardDistance is mu, the expected distance between two random points, sqrt(N/6).
func StandardDistance(dimensions int) float64 { return math.Sqrt(check(dimensions) / 6.0) }

// StandardRadius is the expected distance from the midpoint to a random point, sqrt(N/12).
func StandardRadius(dimensions int) float64 { return math.Sqrt(check(dimensions) / 12.0) }

// StandardDiameter is the expected distance from a corner to a random point, sqrt(N/3).
func StandardDiameter(dimensions int) float64 { return math.Sqrt(check(dimensions) / 3.0) }

// CornerDistance is the expected distance between two random corners, sqrt(N/2).
func CornerDistance(dimensions int) float64 { return math.Sqrt(check(dimensions) / 2.0) }

// HalfDiagonal is midpoint to any corner, exactly sqrt(N/4).
func HalfDiagonal(dimensions int) float64 { return math.Sqrt(check(dimensions) / 4.0) }

// MajorDiagonal is opposite corners, exactly sqrt(N).
func MajorDiagonal(dimensions int) float64 { return math.Sqrt(check(dimensions)) }

// DeviationsBelow is how many standard deviations below mu a distance lies (negative beyond mu).
func DeviationsBelow(dimensions int, distance float64) float64 {
	return (StandardDistance(dimensions) - distance) / StandardDeviation
}

// DistanceAtDeviations is the distance that lies deviations sigma below mu.
func DistanceAtDeviations(dimensions int, deviations float64) float64 {
	return StandardDistance(dimensions) - float64(deviations*StandardDeviation)
}

// BitContent is Eq. III-H: bits of information in two points lying distance apart,
// ((mu - d)/sigma)^2 / ln 2 ~ 24.75*(mu - d)^2. Zero at or beyond standard distance. The book's
// rule of thumb, a little over four bits per dimension at d = 0, falls out of this.
func BitContent(dimensions int, distance float64) float64 {
	x := DeviationsBelow(dimensions, distance)
	if x <= 0 {
		return 0
	}
	return x * x / math.Log(2)
}

// DistanceForBits is the distance at which proximity is worth bits bits; bits must be >= 0.
func DistanceForBits(dimensions int, bits float64) (float64, error) {
	if bits < 0 {
		return 0, fmt.Errorf("%w: bits must be non-negative, got %v", corobs.ErrOutOfRange, bits)
	}
	return StandardDistance(dimensions) - float64(StandardDeviation*math.Sqrt(bits*math.Log(2))), nil
}

// ProbabilityOfProximity is Eq. III-J: the probability that two random points lie closer than
// distance, 10^(-7.45(mu - d)^2) = 2^(-bits). One at or beyond mu.
func ProbabilityOfProximity(dimensions int, distance float64) float64 {
	return math.Pow(2, -BitContent(dimensions, distance))
}

// PointCapacity is Eq. III-Q: how many random points can be placed before two are expected to lie
// closer than distance, 10^(3.7(mu - d)^2).
func PointCapacity(dimensions int, distance float64) float64 {
	gap := StandardDistance(dimensions) - distance
	if gap <= 0 {
		return 1
	}
	return math.Pow(10, 3.7*gap*gap)
}

func check(dimensions int) float64 {
	if dimensions <= 0 {
		panic(fmt.Errorf("%w: a space needs at least one dimension; the statistics hold from about 20 (got %d)", corobs.ErrOutOfRange, dimensions))
	}
	return float64(dimensions)
}
