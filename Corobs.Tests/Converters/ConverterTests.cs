using Corobs.Converters;
using Corobs.Geometry;
using Corobs.Seeding;

namespace Corobs.Tests.Converters;

public sealed class ConverterTests
{
    private const int N = 128;

    [Test]
    public void Cardinal_values_are_fixed_tokens_at_standard_distance_from_each_other()
    {
        var c = new CardinalConverter<string>(new SeededPrng(1), N);
        var again = new CardinalConverter<string>(new SeededPrng(1), N);
        var first = c.Convert("Underclan");
        Assert.That(c.Convert("Underclan"), Is.SameAs(first), "a value is one token, cached");
        Assert.That(again.Convert("Underclan"), Is.EqualTo(first), "same seed, same token, whatever was seen first");
        var mu = NCube.StandardDistance(N);
        Assert.That(c.Convert("Underclan").DistanceTo(c.Convert("Arcturus")) / mu, Is.EqualTo(1).Within(0.2));
        Assert.That(c.Convert(null), Is.EqualTo(Correlithm.Midpoint(N)));
    }

    [Test]
    public void Ordinal_neighbours_are_closer_than_extremes_and_unknowns_throw()
    {
        var tiers = new[] { "street", "runner", "fixer", "corpo", "board" };
        var c = new OrdinalConverter<string>(new SeededPrng(2), N, tiers);
        Assert.That(c.Convert("street").DistanceTo(c.Convert("runner")), Is.LessThan(c.Convert("street").DistanceTo(c.Convert("board"))));
        Assert.That(() => c.Convert("god"), Throws.ArgumentException);
        Assert.That(c.Convert(null), Is.EqualTo(c.Missing));
    }

    [Test]
    public void Continuous_values_interpolate_and_can_wrap()
    {
        var years = new ContinuousConverter(new SeededPrng(3), N, 2200, 2300);
        Assert.That(years.Convert(2230).DistanceTo(years.Convert(2231)), Is.LessThan(years.Convert(2230).DistanceTo(years.Convert(2290))));
        Assert.That(years.Convert(null), Is.EqualTo(years.Missing));
        Assert.That(years.Convert(double.NaN), Is.EqualTo(years.Missing));

        var hours = new ContinuousConverter(new SeededPrng(4), N, 0, 24, wraps: true);
        Assert.That(hours.Convert(23.5).DistanceTo(hours.Convert(0.5)), Is.LessThan(hours.Convert(23.5).DistanceTo(hours.Convert(12))));
    }

    [Test]
    public void Planar_positions_are_near_when_the_map_says_so()
    {
        var map = new PlanarConverter(new SeededPrng(5), N, -10, 10, -10, 10);
        var here = map.Convert((0.0, 0.0));
        Assert.That(here.DistanceTo(map.Convert((0.5, 0.5))), Is.LessThan(here.DistanceTo(map.Convert((8.0, -7.0)))));
        Assert.That(map.Convert(null), Is.EqualTo(map.Missing));
    }
}
