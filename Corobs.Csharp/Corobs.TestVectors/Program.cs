using Corobs.TestVectors;

var root = args.Length > 0 ? args[0] : Vectors.FindRepoRoot(AppContext.BaseDirectory);
var path = Path.Combine(root, "conformance", "vectors.json");
Directory.CreateDirectory(Path.GetDirectoryName(path)!);
File.WriteAllText(path, Vectors.Build());
Console.WriteLine(path);
