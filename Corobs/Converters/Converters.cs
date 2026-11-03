using Corobs.Geometry;
using Corobs.Seeding;
using Corobs.Strings;

namespace Corobs.Converters;

/// <summary>Moves world data into CO space (a <i>sensor</i>, Ch. IX). Every converter answers the
/// same question for a missing value: the cube's midpoint, which carries no bits.</summary>
public interface IConverter<in T>
{
    /// <summary>N: the dimensionality of the points this converter produces.</summary>
    int Dimensions { get; }

    /// <summary>The point for a value, or <see cref="Missing"/> for <c>null</c>.</summary>
    Correlithm Convert(T? value);

    /// <summary>Where an absent value lands: <see cref="Correlithm.Midpoint"/>.</summary>
    Correlithm Missing { get; }
}

/// <summary>A cardinal set — values with no order (a faction, a species, a type): each distinct value
/// gets its own random CO, derived from the seed and the value's key so the mapping is the same on
/// every build regardless of the order values were first seen.</summary>
public sealed class CardinalConverter<T> : IConverter<T> where T : notnull
{
    private readonly SeededPrng _root;
    private readonly Func<T, string> _key;
    private readonly Dictionary<string, Correlithm> _cache = new(StringComparer.Ordinal);

    /// <inheritdoc/>
    public int Dimensions { get; }
    /// <inheritdoc/>
    public Correlithm Missing { get; }

    /// <summary>A cardinal converter over <paramref name="dimensions"/>-dimensional points, each
    /// value's random CO derived from <paramref name="root"/> and the value's key (<paramref name="key"/>,
    /// or <c>ToString()</c> when omitted) so the mapping does not depend on arrival order.</summary>
    public CardinalConverter(SeededPrng root, int dimensions, Func<T, string>? key = null)
    {
        _root = root;
        _key = key ?? (v => v.ToString() ?? "");
        Dimensions = dimensions;
        Missing = Correlithm.Midpoint(dimensions);
    }

    /// <summary>The value's CO (created and cached on first use), or <see cref="Missing"/> for <c>null</c>.</summary>
    public Correlithm Convert(T? value)
    {
        if (value is null) return Missing;
        var k = _key(value);
        if (!_cache.TryGetValue(k, out var co))
            _cache[k] = co = Correlithm.Random(_root.Derive(k), Dimensions);
        return co;
    }
}

/// <summary>An ordinal set — values with an order but no scale (tiers, ranks, an alphabet): evenly
/// spaced positions on a line string CO, so neighbours are near and the extremes are at standard
/// distance (Fig. VII-8). An unknown value is an error, not a guess.</summary>
public sealed class OrdinalConverter<T> : IConverter<T> where T : notnull
{
    private readonly Dictionary<T, int> _index;
    private readonly StringCo _line;

    /// <inheritdoc/>
    public int Dimensions { get; }
    /// <inheritdoc/>
    public Correlithm Missing { get; }
    /// <summary>How many distinct values are in the order.</summary>
    public int Count => _index.Count;

    /// <summary>An ordinal converter whose <paramref name="order"/>-th position is the first, up to
    /// the last, evenly spaced along a fresh line string CO over <paramref name="dimensions"/> dimensions.</summary>
    public OrdinalConverter(SeededPrng prng, int dimensions, IReadOnlyList<T> order, IEqualityComparer<T>? comparer = null)
    {
        if (order.Count == 0) throw new ArgumentException("An ordinal set needs at least one value.", nameof(order));
        _index = new Dictionary<T, int>(comparer);
        for (var i = 0; i < order.Count; i++) _index.Add(order[i], i);
        _line = StringCo.Line(prng, dimensions);
        Dimensions = dimensions;
        Missing = Correlithm.Midpoint(dimensions);
    }

    /// <summary>The value's position on the line (<see cref="Missing"/> for <c>null</c>); throws for a
    /// value outside the ordered set, since there is no sensible place to guess it belongs.</summary>
    public Correlithm Convert(T? value)
    {
        if (value is null) return Missing;
        if (!_index.TryGetValue(value, out var i)) throw new ArgumentException($"'{value}' is not in this ordinal set.", nameof(value));
        return _line.AtIndex(i, _index.Count);
    }
}

/// <summary>A continuous variable on [min, max] — an age, a date, a price — mapped onto a line string
/// CO, or onto a ring when the range wraps (hours of the day, compass bearings).</summary>
public sealed class ContinuousConverter : IConverter<double?>
{
    private readonly StringCo _string;
    private readonly double _min, _max;
    private readonly bool _wraps;

    /// <inheritdoc/>
    public int Dimensions { get; }
    /// <inheritdoc/>
    public Correlithm Missing { get; }

    /// <summary>A continuous converter over [<paramref name="min"/>, <paramref name="max"/>] on a
    /// fresh string CO of <paramref name="dimensions"/> dimensions — a line, or a ring when
    /// <paramref name="wraps"/> (the range's two ends are the same position).</summary>
    public ContinuousConverter(SeededPrng prng, int dimensions, double min, double max, bool wraps = false)
    {
        if (!(max > min)) throw new ArgumentException("max must exceed min.", nameof(max));
        _string = wraps ? StringCo.Ring(prng, dimensions) : StringCo.Line(prng, dimensions);
        (_min, _max, _wraps) = (min, max, wraps);
        Dimensions = dimensions;
        Missing = Correlithm.Midpoint(dimensions);
    }

    /// <summary>The value's point on the string (<see cref="Missing"/> for <c>null</c>, <c>NaN</c>,
    /// or an infinite value on a ring, which has no phase to land on).</summary>
    public Correlithm Convert(double? value)
    {
        if (value is null || double.IsNaN(value.Value)) return Missing;
        // A ring has no position for +/-Infinity (every phase is undefined), so like NaN it is missing.
        if (_wraps && double.IsInfinity(value.Value)) return Missing;
        var t = (value.Value - _min) / (_max - _min);
        return _string.At(t);
    }
}

/// <summary>A point in a bounded plane — a map position — on a planar string CO (Fig. VII-10).</summary>
public sealed class PlanarConverter : IConverter<(double X, double Y)?>
{
    private readonly StringCo _plane;
    private readonly double _minX, _maxX, _minY, _maxY;

    /// <inheritdoc/>
    public int Dimensions { get; }
    /// <inheritdoc/>
    public Correlithm Missing { get; }

    /// <summary>A planar converter over the rectangle [<paramref name="minX"/>, <paramref name="maxX"/>]
    /// × [<paramref name="minY"/>, <paramref name="maxY"/>] on a fresh planar string CO of
    /// <paramref name="dimensions"/> dimensions.</summary>
    public PlanarConverter(SeededPrng prng, int dimensions, double minX, double maxX, double minY, double maxY)
    {
        if (!(maxX > minX) || !(maxY > minY)) throw new ArgumentException("Each axis needs max > min.");
        _plane = StringCo.Plane(prng, dimensions);
        (_minX, _maxX, _minY, _maxY) = (minX, maxX, minY, maxY);
        Dimensions = dimensions;
        Missing = Correlithm.Midpoint(dimensions);
    }

    /// <summary>The value's point on the plane (<see cref="Missing"/> for <c>null</c> or a
    /// <c>NaN</c> coordinate).</summary>
    public Correlithm Convert((double X, double Y)? value)
    {
        if (value is null) return Missing;
        var (x, y) = value.Value;
        if (double.IsNaN(x) || double.IsNaN(y)) return Missing;
        return _plane.At((x - _minX) / (_maxX - _minX), (y - _minY) / (_maxY - _minY));
    }
}
