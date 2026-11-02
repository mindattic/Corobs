namespace Corobs.Tests;

/// <summary>COROBS is pure: the library project references nothing — no package, no project, so no
/// database, no network and no LLM client can ever be reached from it.</summary>
public sealed class PurityTests
{
    [Test]
    public void The_library_project_references_nothing()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        FileInfo? csproj = null;
        while (dir is not null && csproj is null)
        {
            var candidate = Path.Combine(dir.FullName, "Corobs", "Corobs.csproj");
            if (File.Exists(candidate)) csproj = new FileInfo(candidate);
            dir = dir.Parent;
        }
        Assert.That(csproj, Is.Not.Null, "Corobs/Corobs.csproj not found above the test output directory");
        var text = File.ReadAllText(csproj!.FullName);
        Assert.That(text, Does.Not.Contain("<PackageReference"));
        Assert.That(text, Does.Not.Contain("<ProjectReference"));
    }

    [Test]
    public void The_library_assembly_depends_only_on_the_runtime()
    {
        var refs = typeof(Geometry.NCube).Assembly.GetReferencedAssemblies().Select(a => a.Name!).ToArray();
        Assert.That(refs, Has.All.Matches<string>(n => n.StartsWith("System", StringComparison.Ordinal) || n == "netstandard" || n == "mscorlib"));
    }
}
