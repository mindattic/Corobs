---
codex: 1
project: Corobs
code: COR
layer: stories
status: living
updated: 2026-11-01
---
<!-- GENERATED from MindAttic.Tickets/data/Tickets.db by `tickets db render`. Do not edit: this file is rewritten from the database; change stories and tickets with the tickets CLI. -->

# Corobs — User Stories
> ✅ done (shipped & tested) · 🟡 partial · ⬜ planned. Every ✅ cites the test.

## Priority backlog
_Nothing recorded yet._

## Tickets
> Permanent log of every change and fix — this repo's ticket system. Rows are append-only: never
> delete or reword one; only move its Status (open → closed / wont-do) and fill in Ref. Status is
> a word, not a glyph, so tickets don't count toward the story index. Keep this section last.

| ID | Date | Type | Status | Summary | Ref |
|---|---|---|---|---|---|
| COR-T1 | 2026-11-01 | docs | closed | Start the permanent ticket log in the ticket database | — |
| COR-T2 | 2026-11-01 | feature | closed | Corobs: scaffold the pure Correlithm-Object library repo (solution, library, tests, source book in assets, house files) | 28a6c9a |
| COR-T3 | 2026-11-02 | docs | closed | Adopt MindAttic.Agency's docs-site pipeline and publish README to GitHub Pages (HOUSE-LAW-14) | adopt-docs-site.ps1 |
| COR-T4 | 2026-11-02 | fix | closed | Bughunt sweep, two passes: find and fix real bugs across tracked source (user request 2026-11-02) | — |
| COR-T5 | 2026-11-02 | fix | closed | Fix the open items the 2026-11-02 bughunt left for decision (ContinuousConverter wraps: Infinity like NaN) | — |
| COR-T6 | 2026-11-03 | docs | closed | Document every public member against the book; move Prose-specific consumer content out to Prose's own RFC | — |
| COR-T7 | 2026-11-03 | docs | closed | Codify core-stays-pristine and proven, catalogued bug-fix policy in AGENTS.md | — |
| COR-T8 | 2026-11-03 | chore | closed | Retrofit COR-T4/COR-T5 fixes to the bug policy: old code behind per-fix symbols, invariant tests, proofs in docs/BUGS.md | — |
| COR-T9 | 2026-11-05 | feature | open | Restructure into a multi-language repo: C# moves to Corobs.Csharp, root build.ps1 profiles, cross-language conformance vectors generated from the C# reference | — |
| COR-T10 | 2026-11-05 | feature | open | Port Corobs to Python (Corobs.Python): full library, pytest unit tests, passes conformance/vectors.json bit-for-bit | — |
| COR-T11 | 2026-11-05 | feature | open | Port Corobs to C++ (Corobs.Cpp): full library, GoogleTest via CMake unit tests, passes conformance/vectors.json bit-for-bit | — |
| COR-T12 | 2026-11-05 | feature | open | Port Corobs to Java (Corobs.Java): full library, JUnit 5 via Maven unit tests, passes conformance/vectors.json bit-for-bit | — |
| COR-T13 | 2026-11-05 | feature | open | Port Corobs to Rust (Corobs.Rust): full library, cargo test unit tests, passes conformance/vectors.json bit-for-bit | — |
| COR-T14 | 2026-11-05 | feature | open | Port Corobs to TypeScript (Corobs.TypeScript): full library, Vitest unit tests, passes conformance/vectors.json bit-for-bit | — |
| COR-T15 | 2026-11-05 | feature | open | Port Corobs to Go (Corobs.Go): full library, go test unit tests, passes conformance/vectors.json bit-for-bit | — |
| COR-T16 | 2026-11-05 | feature | open | Port Corobs to Swift (Corobs.Swift): full library, Swift Testing via SwiftPM unit tests, passes conformance/vectors.json bit-for-bit | — |
| COR-T17 | 2026-11-05 | feature | open | Port Corobs to Julia (Corobs.Julia): full library, Test stdlib via Pkg unit tests, passes conformance/vectors.json bit-for-bit | — |
