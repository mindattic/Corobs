using Corobs.Converters;
using Corobs.Seeding;

namespace Corobs.Tests.Bugs;

/// <summary>COR-T5 is a decision, not a proven error (docs/BUGS.md): this test pins the chosen
/// behaviour so the symbol build shows exactly what reverting it changes.</summary>
public sealed class COR_T5Tests
{
    [TestCase(double.PositiveInfinity)]
    [TestCase(double.NegativeInfinity)]
    public void Decision_a_wrapping_converter_maps_infinity_to_missing(double value)
    {
        var hours = new ContinuousConverter(new SeededPrng(1), 32, 0, 24, wraps: true);
        Assert.That(hours.Convert(value), Is.EqualTo(hours.Missing));
    }
}
