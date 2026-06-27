---
name: spec-driven-port-grind
description: Harden a reference implementation AND its spec by reimplementing it across many languages as dependency-free, property-tested conformance probes. Cross-port disagreement reveals spec ambiguities and real bugs in the reference; fold findings back. Use when you have a spec + a reference impl and want to battle-test both, or to drive a multi-language "grind" with round-based spec versioning.
---

# spec-driven-port-grind

Reimplement a spec across a fleet of languages as **conformance probes**. The
ports are ephemeral — their value is what they *reveal*: where independent
implementers disagree is exactly where the spec is underspecified or the
reference is wrong. Fold findings back into the spec + reference. Repeat.

## The loop
1. **Spec + reference exist.** One canonical impl (e.g. guile-sage) + a
   language-agnostic boundary spec (`spec.org`).
2. **Grind a round:** spawn one agent per language, in parallel. Each builds a
   port against the spec.
3. **Harvest:** collect each team's findings (spec ambiguities + bugs). *Cross-port
   AGREEMENT is the strongest signal* — if 4 independent ports hit the same gap,
   it's real, not a one-off.
4. **Fold forward:** fix the reference (with regression tests), tighten the spec.
5. **Version + repeat** with new languages.

## Round-based spec versioning
**A grind vN consumes spec v(N−1) and produces spec vN.** Each round builds
against the previous spec; its findings harden the spec into the same-numbered
version. The *reference(s)* always track the latest version ("we always learn").
A spec version is independent of an impl's own release version. From a chosen
round on, teams track upgrade/regression work in **beads** (`bd`), which feeds
the next version.

## Build-team protocol (the lean handoff)
Each team gets **exactly two things: the spec + a meta directive** (see
`PORT-BUILD-DIRECTIVE`). No hand-fed boundary checklist — deriving the contract
from the spec is part of the job, and where it's unclear is a finding.
- **Dependency-free.** Stdlib/runtime only; hand-roll JSON + a property harness
  if the language ships none.
- **Property-based testing is the test layer**; the runner MUST exit non-zero on
  any failure — *no masked greens*.
- **`gmake` convention:** `help` (awk-only, default), `build`, `check`, `run`,
  plus whatever entrypoint the spec needs (e.g. `mcp-server`).
- **Local/ephemeral**, no secrets, no private IPs.
- Implement the priority boundaries fully; **stub the rest** with explicit
  "not implemented" (never fake) + spec-tagged TODOs.
- **Ship a `CLAUDE.md`** continuation guide: build/test/run commands + runtime
  version, implemented-vs-stubbed by spec §, gotchas, spec ambiguities found.

## Picking languages (diversity is the point)
Each paradigm stresses a different part of the spec:
- **Typed FP** (Haskell/OCaml/Scala/Rust): a sum type forces the
  null / empty-object / absent distinction the spec blurs; exhaustiveness exposes
  underspecified cases; the trust lattice becomes a real ADT.
- **Manual memory** (C/C++/Zig): forces *proving* byte-faithfulness (the taint
  envelope can't overflow) rather than assuming it.
- **Sibling dialects** (Chez/Racket vs Guile; SBCL vs ECL; bare Erlang vs Elixir):
  flush out host-specific idioms accidentally baked into the spec.
- **Extreme-constraint** (AWK, Tcl, Io): what's *awkward or impossible* reveals
  what the spec quietly assumes about data structures. Expect many honest stubs;
  the stub list is the deliverable.
- **Dynamic** (Python/Ruby/Perl/Clojure): the convention decisions (key types,
  int coercion) the spec must pin.

## Orchestration
- `mkdir` a repo per language, copy the spec in, launch one agent each (parallel).
- Verify each on landing (build + tests green), then harvest.
- Don't edit a port while its agent runs (CLAUDE.md/deps conflicts).
- Toolchain: check what's installed first; centralize FreeBSD `pkg` deps in a
  `gmake deps-cohort` target.

## Worked example (guile-sage, 2026)
3 rounds, ~20 languages (Python → Perl), references = guile-sage (Guile) +
sage-clojure. The ports found **real bugs in the reference**: an MCP no-oracle
leak (gated vs unknown tool distinguishable), `safe-path?` both over- and
under-blocking (`my.env` vs `/tmp/.ssh` vs `.env.local` — fixed to a per-token
rule), control-byte injection into error transcripts, and a config-precedence
spec/impl contradiction — plus ~18 spec clarifications. Every fix traceable to a
port team; the typed ports' `Eq`/exhaustiveness checks caught what review missed.

## Gotchas (learned)
- `bd setup claude` **overwrites `CLAUDE.md`** — run it before writing the guide.
- Stale `~/.cache/guile/ccache` can shadow a version banner — wrappers should
  `--no-auto-compile` against the installed cache.
- Some runtimes' spawn primitives crash a long-lived VM (Guile `system*`
  SIGSEGV) — host-specific, NOT a cross-language spec rule.
