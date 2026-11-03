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
- **Measurement, never judgment.** This library ranks and cues; it never decides. Confirmation of a
  pattern or rule, and resolution of a hit, are the caller's hand decisions carrying an id.
