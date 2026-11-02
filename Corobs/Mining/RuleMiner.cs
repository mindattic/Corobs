namespace Corobs.Mining;

/// <summary>
/// A rule <c>s.p &gt;: t.q</c> (Ch. IV): things inside pattern <see cref="Source"/> on ply
/// <see cref="SourcePly"/> are found inside pattern <see cref="Target"/> on ply <see cref="TargetPly"/>
/// with the given <see cref="Support"/>. These are the strings that pull.
/// </summary>
public sealed record Rule<TId>(string SourcePly, Pattern<TId> Source, string TargetPly, Pattern<TId> Target, double Support, double Bits)
    where TId : notnull
{
    public override string ToString() => $"{SourcePly}.[{Source.Members.Count}] >: {TargetPly}.[{Target.Members.Count}] support {Support:P0}, {Bits:F1} bits";
}

/// <summary>
/// Proposes rules between the patterns of two plies: for every source pattern, the target pattern
/// that holds the largest share of its members, kept when that share reaches
/// <see cref="MinSupport"/>. Bits = support × the source pattern's bits. Deterministic.
/// </summary>
public sealed class RuleMiner
{
    public double MinSupport { get; }

    public RuleMiner(double minSupport = 0.8)
    {
        if (minSupport <= 0 || minSupport > 1) throw new ArgumentOutOfRangeException(nameof(minSupport));
        MinSupport = minSupport;
    }

    public IReadOnlyList<Rule<TId>> Mine<TId>(string sourcePly, IReadOnlyList<Pattern<TId>> source, string targetPly, IReadOnlyList<Pattern<TId>> target)
        where TId : notnull
    {
        if (string.Equals(sourcePly, targetPly, StringComparison.Ordinal)) throw new ArgumentException("A rule relates two different plies.", nameof(targetPly));
        var rules = new List<Rule<TId>>();
        foreach (var p in source)
        {
            Pattern<TId>? best = null; var bestCount = 0;
            foreach (var q in target)
            {
                var count = p.Members.Count(q.Contains);
                if (count > bestCount) { best = q; bestCount = count; }
            }
            if (best is null) continue;
            var support = bestCount / (double)p.Members.Count;
            if (support >= MinSupport) rules.Add(new Rule<TId>(sourcePly, p, targetPly, best, support, support * p.Bits));
        }
        return rules.OrderByDescending(r => r.Bits).ToArray();
    }
}
