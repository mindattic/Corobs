using Corobs.TestVectors;

namespace Corobs.Tests;

/// <summary>conformance/vectors.json is what every language port must reproduce; it must stay exactly
/// what this reference implementation produces. Regenerate with build.ps1 -Profile Vectors.</summary>
public sealed class ConformanceTests
{
    [Test]
    public void The_committed_vectors_are_what_the_reference_produces()
    {
        var path = Path.Combine(Vectors.FindRepoRoot(AppContext.BaseDirectory), "conformance", "vectors.json");
        Assert.That(File.Exists(path), Is.True, path + " is missing; run build.ps1 -Profile Vectors");
        Assert.That(File.ReadAllText(path).Replace("\r\n", "\n"), Is.EqualTo(Vectors.Build()),
            "conformance/vectors.json is stale; run build.ps1 -Profile Vectors and commit the result");
    }
}
