using Corobs.Seeding;

namespace Corobs.Bench;

/// <summary>How well a neighbour function recovers relationships that were hidden from it.</summary>
public sealed record RecallResult(int Hidden, int Recovered, int Predicted, int PredictedTrue)
{
    /// <summary>Share of the hidden pairs that the predictor recovered.</summary>
    public double Recall => Hidden == 0 ? 0 : Recovered / (double)Hidden;
    /// <summary>Share of the predictor's own guesses that were actually true (anywhere in the full truth).</summary>
    public double Precision => Predicted == 0 ? 0 : PredictedTrue / (double)Predicted;
}

/// <summary>How far a thing can reach through a relationship: mean reachable count per hop and how
/// many things reach nothing at all (dead records).</summary>
public sealed record ReachResult(IReadOnlyList<double> MeanReachableByHop, int Isolated, int Total);

/// <summary>
/// Scores any way of relating things against any other on the same ground truth — the old way and
/// the COROBS way answer the same questions, and these are the questions. Everything here is
/// arithmetic over ids; the caller supplies the truth and the predictors.
/// </summary>
public static class Bench
{
    /// <summary>Hide <paramref name="holdoutFraction"/> of the true pairs (deterministically, by seed),
    /// ask the predictor for each hidden endpoint's neighbours, and count how many hidden pairs come
    /// back. Precision counts predicted neighbours of those endpoints that are true pairs anywhere in
    /// the full truth.</summary>
    public static RecallResult HoldoutRecall<TId>(IReadOnlyList<(TId A, TId B)> truePairs, double holdoutFraction, long seed, Func<TId, IReadOnlyCollection<TId>> neighbours, IEqualityComparer<TId>? comparer = null)
        where TId : notnull
    {
        if (holdoutFraction <= 0 || holdoutFraction >= 1) throw new ArgumentOutOfRangeException(nameof(holdoutFraction));
        var cmp = comparer ?? EqualityComparer<TId>.Default;
        var pairCmp = new PairComparer<TId>(cmp);
        var truth = new HashSet<(TId, TId)>(truePairs.Select(Canon), pairCmp);

        var prng = new SeededPrng(seed);
        // Distinct pairs only (first occurrence kept, so input without duplicates shuffles as before):
        // a pair listed twice, or both ways round, is one relationship, not two to hide.
        var shuffled = truePairs.Select(Canon).Distinct(pairCmp).ToArray();
        for (var i = shuffled.Length - 1; i > 0; i--) { var j = prng.Next(i + 1); (shuffled[i], shuffled[j]) = (shuffled[j], shuffled[i]); }
        var hidden = shuffled.Take((int)Math.Round(shuffled.Length * holdoutFraction)).Select(Canon).ToArray();
        var hiddenSet = new HashSet<(TId, TId)>(hidden, new PairComparer<TId>(cmp));

        var recovered = 0; var predicted = 0; var predictedTrue = 0;
        var endpoints = new HashSet<TId>(hidden.SelectMany(p => new[] { p.Item1, p.Item2 }), cmp);
        var seen = new HashSet<(TId, TId)>(new PairComparer<TId>(cmp));
        foreach (var e in endpoints)
            foreach (var nb in neighbours(e))
            {
                var pair = Canon((e, nb));
                if (!seen.Add(pair)) continue;
                predicted++;
                if (truth.Contains(pair)) predictedTrue++;
                if (hiddenSet.Remove(pair)) recovered++;
            }
        return new RecallResult(hidden.Length, recovered, predicted, predictedTrue);

        (TId, TId) Canon((TId A, TId B) p) => string.CompareOrdinal(p.A.ToString(), p.B.ToString()) <= 0 ? (p.A, p.B) : (p.B, p.A);
    }

    /// <summary>Breadth-first reach from every id through <paramref name="adjacency"/>, up to
    /// <paramref name="maxHops"/>.</summary>
    public static ReachResult Reach<TId>(IReadOnlyCollection<TId> ids, Func<TId, IEnumerable<TId>> adjacency, int maxHops, IEqualityComparer<TId>? comparer = null)
        where TId : notnull
    {
        if (maxHops <= 0) throw new ArgumentOutOfRangeException(nameof(maxHops));
        var cmp = comparer ?? EqualityComparer<TId>.Default;
        var sums = new double[maxHops];
        var isolated = 0;
        foreach (var start in ids)
        {
            var visited = new HashSet<TId>(cmp) { start };
            var frontier = new List<TId> { start };
            var reached = 0;
            for (var hop = 0; hop < maxHops; hop++)
            {
                var next = new List<TId>();
                foreach (var f in frontier)
                    foreach (var a in adjacency(f))
                        if (visited.Add(a)) next.Add(a);
                reached += next.Count;
                sums[hop] += reached;
                frontier = next;
                if (next.Count == 0) { for (var h = hop + 1; h < maxHops; h++) sums[h] += reached; break; }
            }
            if (reached == 0) isolated++;
        }
        var means = sums.Select(s => ids.Count == 0 ? 0 : s / ids.Count).ToArray();
        return new ReachResult(means, isolated, ids.Count);
    }

    /// <summary>Hits that closed because something else was fixed, per direct fix. The old way scores
    /// zero by construction; that is a fact to report, not to hide.</summary>
    public static double CascadeYield(int closedByCascade, int directFixes)
        => directFixes == 0 ? 0 : closedByCascade / (double)directFixes;

    private sealed class PairComparer<TId>(IEqualityComparer<TId> inner) : IEqualityComparer<(TId, TId)> where TId : notnull
    {
        // Unordered: (a, b) and (b, a) are one pair under the caller's comparer, whatever ToString says.
        public bool Equals((TId, TId) x, (TId, TId) y)
            => (inner.Equals(x.Item1, y.Item1) && inner.Equals(x.Item2, y.Item2))
            || (inner.Equals(x.Item1, y.Item2) && inner.Equals(x.Item2, y.Item1));
        public int GetHashCode((TId, TId) p) => inner.GetHashCode(p.Item1) ^ inner.GetHashCode(p.Item2);
    }
}
