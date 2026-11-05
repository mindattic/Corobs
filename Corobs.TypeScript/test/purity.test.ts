import { readdirSync, readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";

/** COROBS is pure: no runtime dependency, so no database, network or LLM client can be reached. */
describe("purity", () => {
  const root = new URL("../", import.meta.url);

  it("the package declares no runtime dependencies", () => {
    const pkg = JSON.parse(readFileSync(new URL("package.json", root), "utf8")) as Record<string, unknown>;
    for (const field of ["dependencies", "peerDependencies", "optionalDependencies", "bundleDependencies", "bundledDependencies"]) {
      const deps = pkg[field];
      expect(deps === undefined || Object.keys(deps as object).length === 0, `package.json ${field} must be empty`).toBe(true);
    }
  });

  it("the library imports nothing but its own modules", () => {
    const src = new URL("src/", root);
    const files = readdirSync(src).filter((f) => f.endsWith(".ts"));
    expect(files.length).toBeGreaterThan(0);
    const specifier = /(?:\bfrom\s*|\bimport\s*\(?\s*|\brequire\s*\(\s*)["']([^"']+)["']/g;
    for (const f of files) {
      const text = readFileSync(new URL(f, src), "utf8");
      for (const m of text.matchAll(specifier)) expect(m[1]!.startsWith("./"), `${f} imports ${m[1]}`).toBe(true);
    }
  });
});
