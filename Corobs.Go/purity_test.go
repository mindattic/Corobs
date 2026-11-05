package corobs_test

import (
	"go/parser"
	"go/token"
	"io/fs"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
)

// COROBS is pure: no third-party module, and the library imports nothing but the standard library
// and its own packages, so no database, network or LLM client can ever be reached from it.

const module = "github.com/mindattic/Corobs/Corobs.Go"

func TestGoModRequiresNothing(t *testing.T) {
	raw, err := os.ReadFile("go.mod")
	if err != nil {
		t.Fatal(err)
	}
	for _, line := range strings.Split(string(raw), "\n") {
		if strings.HasPrefix(strings.TrimSpace(line), "require") {
			t.Fatalf("go.mod requires a module: %q", line)
		}
	}
}

func TestTheLibraryImportsOnlyTheStandardLibrary(t *testing.T) {
	files := 0
	err := filepath.WalkDir(".", func(path string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() || !strings.HasSuffix(path, ".go") || strings.HasSuffix(path, "_test.go") {
			return err
		}
		files++
		f, err := parser.ParseFile(token.NewFileSet(), path, nil, parser.ImportsOnly)
		if err != nil {
			return err
		}
		for _, imp := range f.Imports {
			p, _ := strconv.Unquote(imp.Path.Value)
			first := strings.SplitN(p, "/", 2)[0]
			if p != module && !strings.HasPrefix(p, module+"/") && strings.Contains(first, ".") {
				t.Errorf("%s imports %s, which is not the standard library", path, p)
			}
		}
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	if files == 0 {
		t.Fatal("no library files found")
	}
}
