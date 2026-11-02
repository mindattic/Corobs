using Corobs.Geometry;

namespace Corobs.Mining;

/// <summary>
/// A ranked contradiction candidate: a thing that sits inside a rule's source pattern yet lies at or
/// near standard distance from the rule's target — the anomaly a cueing system hands to the expert
/// (Ch. X–XI). What to do about it is the caller's hand decision.
/// </summary>
public sealed record Hit<TId>(TId Id, Rule<TId> Rule, double SourceDistance, double TargetDistance, double Bits, int Rank)
    where TId : notnull
{
    public override string ToString() => $"#{Rank} {Id}: {Bits:F1} bits — {Rule}";
}

/// <summary>
/// For every rule, every member of its source whose point on the target ply lies no closer than
/// <see cref="TargetDeviations"/> σ below standard distance from the target centroid is a hit. Bits =
/// (bits of the member's own distance to the source centroid) × rule support, so a thing deep inside a
/// strong source that misses the target outranks a marginal member of a weak one. Deterministic.
/// </summary>
public sealed class Cue
{
    public double TargetDeviations { get; }

    public Cue(double targetDeviations = 1)
    {
        if (targetDeviations < 0) throw new ArgumentOutOfRangeException(nameof(targetDeviations));
        TargetDeviations = targetDeviations;
    }

    /// <param name="rules">Confirmed rules.</param>
    /// <param name="plies">Each ply's points by id, keyed by ply name.</param>
    /// <param name="order">Tie-break order for ids at equal bits; the default comparer when null.</param>
    public IReadOnlyList<Hit<TId>> Find<TId>(IReadOnlyList<Rule<TId>> rules, IReadOnlyDictionary<string, IReadOnlyDictionary<TId, Correlithm>> plies, IComparer<TId>? order = null)
        where TId : notnull
    {
        var cmp = order ?? Comparer<TId>.Default;
        var hits = new List<Hit<TId>>();
        foreach (var rule in rules)
        {
            if (!plies.TryGetValue(rule.SourcePly, out var sourcePoints)) throw new ArgumentException($"No points for ply '{rule.SourcePly}'.", nameof(plies));
            if (!plies.TryGetValue(rule.TargetPly, out var targetPoints)) throw new ArgumentException($"No points for ply '{rule.TargetPly}'.", nameof(plies));
            var n = rule.Target.Centroid.Dimensions;
            var farEnough = NCube.DistanceAtDeviations(n, TargetDeviations);
            foreach (var id in rule.Source.Members)
            {
                if (!targetPoints.TryGetValue(id, out var tp) || !sourcePoints.TryGetValue(id, out var sp)) continue;
                var targetDistance = tp.DistanceTo(rule.Target.Centroid);
                if (targetDistance < farEnough) continue;
                var sourceDistance = sp.DistanceTo(rule.Source.Centroid);
                var bits = NCube.BitContent(sp.Dimensions, sourceDistance) * rule.Support;
                hits.Add(new Hit<TId>(id, rule, sourceDistance, targetDistance, bits, 0));
            }
        }
        return hits.OrderByDescending(h => h.Bits).ThenBy(h => h.Id, cmp)
                   .Select((h, i) => h with { Rank = i + 1 }).ToArray();
    }
}
