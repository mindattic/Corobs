package converters

import (
	"errors"
	"math"
	"testing"

	corobs "github.com/mindattic/Corobs/Corobs.Go"
	"github.com/mindattic/Corobs/Corobs.Go/geometry"
	"github.com/mindattic/Corobs/Corobs.Go/seeding"
)

const n = 128

func conv[T any](t *testing.T, c Converter[T], v *T) geometry.Correlithm {
	t.Helper()
	p, err := c.Convert(v)
	if err != nil {
		t.Fatal(err)
	}
	return p
}

func ptr[T any](v T) *T { return &v }

func TestCardinalValuesAreFixedTokensAtStandardDistanceFromEachOther(t *testing.T) {
	c := NewCardinal[string](seeding.New(1), n, nil)
	again := NewCardinal[string](seeding.New(1), n, nil)
	again.Convert(ptr("Arcturus")) // seen in a different order
	first := conv[string](t, c, ptr("Underclan"))
	if !conv[string](t, c, ptr("Underclan")).Equal(first) {
		t.Fatal("a value is one token, cached")
	}
	if !conv[string](t, again, ptr("Underclan")).Equal(first) {
		t.Fatal("same seed, same token, whatever was seen first")
	}
	mu := geometry.StandardDistance(n)
	if r := conv[string](t, c, ptr("Underclan")).DistanceTo(conv[string](t, c, ptr("Arcturus"))) / mu; math.Abs(r-1) > 0.2 {
		t.Fatalf("distinct values at %v mu, want ~1", r)
	}
	if !conv[string](t, c, nil).Equal(geometry.Midpoint(n)) {
		t.Fatal("missing is the midpoint")
	}
}

func TestCardinalUsesTheCallersKey(t *testing.T) {
	type faction struct{ name string }
	c := NewCardinal(seeding.New(1), n, func(f faction) string { return f.name })
	byName := NewCardinal[string](seeding.New(1), n, nil)
	if !conv[faction](t, c, &faction{"Underclan"}).Equal(conv[string](t, byName, ptr("Underclan"))) {
		t.Fatal("the key decides the token")
	}
}

func TestOrdinalNeighboursAreCloserThanExtremesAndUnknownsFail(t *testing.T) {
	tiers := []string{"street", "runner", "fixer", "corpo", "board"}
	c, err := NewOrdinal(seeding.New(2), n, tiers)
	if err != nil {
		t.Fatal(err)
	}
	street := conv[string](t, c, ptr("street"))
	if !(street.DistanceTo(conv[string](t, c, ptr("runner"))) < street.DistanceTo(conv[string](t, c, ptr("board")))) {
		t.Fatal("neighbours must be closer than extremes")
	}
	if _, err := c.Convert(ptr("god")); !errors.Is(err, corobs.ErrArgument) {
		t.Fatalf("unknown value: %v", err)
	}
	if !conv[string](t, c, nil).Equal(c.Missing()) {
		t.Fatal("missing")
	}
	if c.Count() != 5 || c.Dimensions() != n {
		t.Fatal("count/dimensions")
	}
	if _, err := NewOrdinal[string](seeding.New(2), n, nil); !errors.Is(err, corobs.ErrArgument) {
		t.Fatalf("empty order: %v", err)
	}
	if _, err := NewOrdinal(seeding.New(2), n, []string{"a", "a"}); !errors.Is(err, corobs.ErrArgument) {
		t.Fatalf("duplicate order: %v", err)
	}
}

func TestContinuousValuesInterpolateAndCanWrap(t *testing.T) {
	years, err := NewContinuous(seeding.New(3), n, 2200, 2300, false)
	if err != nil {
		t.Fatal(err)
	}
	y2230 := conv[float64](t, years, ptr(2230.0))
	if !(y2230.DistanceTo(conv[float64](t, years, ptr(2231.0))) < y2230.DistanceTo(conv[float64](t, years, ptr(2290.0)))) {
		t.Fatal("near years must be near")
	}
	if !conv[float64](t, years, nil).Equal(years.Missing()) || !conv[float64](t, years, ptr(math.NaN())).Equal(years.Missing()) {
		t.Fatal("nil and NaN are missing")
	}

	hours, err := NewContinuous(seeding.New(4), n, 0, 24, true)
	if err != nil {
		t.Fatal(err)
	}
	late := conv[float64](t, hours, ptr(23.5))
	if !(late.DistanceTo(conv[float64](t, hours, ptr(0.5))) < late.DistanceTo(conv[float64](t, hours, ptr(12.0)))) {
		t.Fatal("23:30 is next to 00:30 on a ring")
	}
	if _, err := NewContinuous(seeding.New(4), n, 5, 5, false); !errors.Is(err, corobs.ErrArgument) {
		t.Fatalf("max == min: %v", err)
	}
}

func TestPlanarPositionsAreNearWhenTheMapSaysSo(t *testing.T) {
	m, err := NewPlanar(seeding.New(5), n, -10, 10, -10, 10)
	if err != nil {
		t.Fatal(err)
	}
	here := conv[XY](t, m, &XY{0, 0})
	if !(here.DistanceTo(conv[XY](t, m, &XY{0.5, 0.5})) < here.DistanceTo(conv[XY](t, m, &XY{8, -7}))) {
		t.Fatal("near on the map must be near in the cube")
	}
	if !conv[XY](t, m, nil).Equal(m.Missing()) || !conv[XY](t, m, &XY{math.NaN(), 1}).Equal(m.Missing()) {
		t.Fatal("nil and NaN are missing")
	}
	if _, err := NewPlanar(seeding.New(5), n, 0, 1, 2, 2); !errors.Is(err, corobs.ErrArgument) {
		t.Fatalf("degenerate axis: %v", err)
	}
}
