using Corobs.Geometry;

namespace Corobs.Mining;

/// <summary>
/// Finds the clusters on one ply that are far tighter than chance: two points are linked when they lie
/// at least <see cref="MinDeviations"/> σ below standard distance (≈ 52 bits at 6σ — Eq. III-H), linked
/// points are joined by union-find, and a component with at least <see cref="MinMembers"/> members is a
/// proposed <see cref="Pattern{TId}"/>. Deterministic: points are processed in id order, and the
/// output is ordered by bits then by first member.
/// </summary>
public sealed class PatternMiner
{
    public double MinDeviations { get; }
    public int MinMembers { get; }

    public PatternMiner(double minDeviations = 6, int minMembers = 5)
    {
        if (minDeviations <= 0) throw new ArgumentOutOfRangeException(nameof(minDeviations));
        if (minMembers < 2) throw new ArgumentOutOfRangeException(nameof(minMembers));
        MinDeviations = minDeviations;
        MinMembers = minMembers;
    }

    public IReadOnlyList<Pattern<TId>> Mine<TId>(IReadOnlyList<PlyPoint<TId>> points, IComparer<TId>? order = null, IEqualityComparer<TId>? equality = null)
        where TId : notnull
    {
        if (points.Count < MinMembers) return [];
        var n = points[0].Point.Dimensions;
        var cmp = order ?? Comparer<TId>.Default;
        var sorted = points.OrderBy(p => p.Id, cmp).ToArray();
        var threshold = NCube.DistanceAtDeviations(n, MinDeviations);
        var thresholdSq = threshold * threshold;

        var parent = new int[sorted.Length];
        for (var i = 0; i < parent.Length; i++) parent[i] = i;

        for (var i = 0; i < sorted.Length; i++)
        {
            var pi = sorted[i].Point;
            for (var j = i + 1; j < sorted.Length; j++)
                if (pi.SquaredDistanceTo(sorted[j].Point) <= thresholdSq) Union(parent, i, j);
        }

        var groups = new Dictionary<int, List<int>>();
        for (var i = 0; i < sorted.Length; i++)
        {
            var root = Find(parent, i);
            if (!groups.TryGetValue(root, out var list)) groups[root] = list = [];
            list.Add(i);
        }

        var result = new List<Pattern<TId>>();
        foreach (var members in groups.Values.Where(g => g.Count >= MinMembers))
        {
            var pts = members.Select(i => sorted[i].Point).ToArray();
            var centroid = Correlithm.Centroid(pts);
            var radius = pts.Max(p => p.DistanceTo(centroid));
            double sum = 0; var pairs = 0;
            for (var a = 0; a < pts.Length; a++)
                for (var b = a + 1; b < pts.Length; b++) { sum += pts[a].DistanceTo(pts[b]); pairs++; }
            var mean = sum / pairs;
            result.Add(new Pattern<TId>(members.Select(i => sorted[i].Id).ToArray(), centroid, radius, mean, NCube.BitContent(n, mean), equality));
        }

        return result.OrderByDescending(p => p.Bits).ThenBy(p => p.Members[0], cmp).ToArray();
    }

    private static int Find(int[] parent, int i)
    {
        while (parent[i] != i) { parent[i] = parent[parent[i]]; i = parent[i]; }
        return i;
    }

    private static void Union(int[] parent, int a, int b)
    {
        var ra = Find(parent, a); var rb = Find(parent, b);
        if (ra == rb) return;
        if (ra < rb) parent[rb] = ra; else parent[ra] = rb;
    }
}
