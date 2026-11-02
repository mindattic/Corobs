using Corobs.Geometry;

namespace Corobs.Mining;

/// <summary>One thing's position on one ply (subspace).</summary>
public sealed record PlyPoint<TId>(TId Id, Correlithm Point) where TId : notnull;

/// <summary>
/// An emergent truth: a set of things whose points on one ply lie far closer together than chance
/// allows. Proposed by <see cref="PatternMiner"/>; what it <i>means</i>, and whether it is true, is
/// the caller's hand decision.
/// </summary>
public sealed class Pattern<TId> where TId : notnull
{
    public IReadOnlyList<TId> Members { get; }
    public Correlithm Centroid { get; }

    /// <summary>The furthest any member lies from the centroid.</summary>
    public double Radius { get; }

    /// <summary>The mean distance between members, pairwise.</summary>
    public double MeanPairDistance { get; }

    /// <summary>Eq. III-H bits of the mean pair distance: how far below chance this cluster is.</summary>
    public double Bits { get; }

    private readonly HashSet<TId> _set;

    public Pattern(IReadOnlyList<TId> members, Correlithm centroid, double radius, double meanPairDistance, double bits, IEqualityComparer<TId>? comparer = null)
    {
        Members = members;
        Centroid = centroid;
        Radius = radius;
        MeanPairDistance = meanPairDistance;
        Bits = bits;
        _set = new HashSet<TId>(members, comparer);
    }

    public bool Contains(TId id) => _set.Contains(id);

    public override string ToString() => $"Pattern[{Members.Count} members, {Bits:F1} bits]";
}
