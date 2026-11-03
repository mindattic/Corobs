# MindAttic project agent entrypoint

Read the shared protocol at ..\mindattic-agent-standard\AGENTS.md and this project's own
documentation (README.md, docs/). Common prompt commands are implemented by the shared runner; do
not add a second copy under a provider-specific command folder.

## This repo's own rules

- **COROBS is pure.** `Corobs/` references no MindAttic application, no database, no network and
  no LLM client. Everything is deterministic under a seed: same seed, same inputs, same bits. A test
  asserts the project file carries no such reference. Consumers write their own adapters on their
  side of the line, and document why they use this library in their own repository, not here.
- **The source book is the specification.** Dr. P. Nick Lawrence's *Correlithm Object Technology*
  (2004) lives in the private companion repo `mindattic/Corobs-Book`, checked out at `book/` here
  (git-ignored). Cite chapter and equation (e.g. Table II-1, Eq. III-H) in code comments and tests
  when a number comes from the book. The book is copyrighted: it never enters this public
  repository — not under `assets/`, not anywhere. `assets/` is for diagrams and other public material.
- **The core stays pristine; enhancements are extensions.** Corobs implements the book and nothing
  more. New capability, tuning or product-specific behaviour goes in a separate library that
  references Corobs: generic extensions under their own name, product adapters as
  `Corobs.<Product>` (e.g. `Corobs.Prose.dll`), which live and are documented in that product's own
  repository. Nothing in this repo names, references or exists for a particular product.
- **Bugs are fixed here, proven and catalogued.** A divergence from the book, or a plain defect, is
  fixed in Corobs itself, never worked around in an extension. Every fix:
  1. carries its own ticket (`tickets ticket new --type fix`), cited in the commit;
  2. keeps the old code beside the new behind its own compiler symbol, `COROBS_BUG_COR_Tn[_PART]`:
     `#if SYMBOL` (old) / `#else` (fixed) / `#endif`, or `#if !SYMBOL` around code the fix only
     added, with a one-line comment naming the ticket and docs/BUGS.md;
  3. adds a test in `Corobs.Tests/Bugs/` that asserts an invariant (from the book where one
     applies), not the new implementation;
  4. records the proof in `docs/BUGS.md`. The proof is mathematical, checked against the book (PDF
     for equations), and classifies the fix as book divergence, implementation defect, or decision.
     A decision has no proof, so it is labelled as one and left for the owner to keep or revert.
  The default build compiles the fix and the test passes. `dotnet test -p:CorobsBugs=SYMBOL`
  compiles the old code and the same test must fail. That failure is the empirical proof.
- **Measurement, never judgment.** This library ranks and cues; it never decides. Confirmation of a
  pattern or rule, and resolution of a hit, are the caller's hand decisions carrying an id.
