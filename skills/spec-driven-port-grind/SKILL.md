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
  the stub list is the deliverable. **A graceful bail — "this isn't reasonably
  expressible in <lang>", with the impossibility list — is a FIRST-CLASS result,
  not a failure.** Don't force a tortured implementation; document the wall and
  what it implies about the spec's assumptions.
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

## When this works — project fit (the meta)
This grind pays off **only for projects amenable to unit/property-based testing** —
where the spec is expressible as *testable boundaries*:
- **pure-ish functions** with checkable contracts (parse/encode, escape/unescape,
  path validation, error normalization, classification);
- properties that hold for *all inputs* — round-trip, totality, invariant,
  partition (see `dsp-dr/pbt-polyglot`);
- a wire/protocol you can drive deterministically (here: stdio JSON-RPC).

It does **not** transfer to projects dominated by stateful UI, aesthetic/fuzzy
output, emergent behavior, or anything you can't pin to an assertion. The tell:
*can a fresh implementer, given only the spec, write a property that fails on a
wrong implementation?* If yes, grind. If no, this isn't the tool — the "ports"
would have nothing objective to converge on, so disagreement wouldn't be signal.
The boundary layer is grindable; the agent-loop/UX surface (stubbed in every
port) is not — which is exactly why ports stub it.

## Spec-version upgrades: the cost-of-drift experiment
Beyond fresh ports, a sharp second experiment: measure *how expensive it is to
keep an existing codebase current with the spec*. Take ports built against
different baseline versions and **upgrade each to the latest spec, in reverse
order** (newest baseline first → oldest last):
- `v4-era port → v5` (1 version of drift; cheapest),
- `v3-era → v5`, `v2-era → v5`,
- `v1-era → v5` (max drift; most expensive).

Each upgrade is **beads-tracked** (`bd create` per conformance gap hit, `bd close`
when resolved); the *bead count + wall-clock per step* plots the **cost-of-drift
curve**. Reverse order means each step's findings prime the next (you learn the
v5 deltas on the easy 1-version jump before attempting the 4-version one).

Two readings:
- a **single-version** jump (`vN-1 → vN`) = the realistic *stay-current*
  maintenance cost — the number the per-round beads loop is designed to keep low;
- a **multi-version** jump (`v1 → vN`) = the *skip-versions* penalty — how bad
  drift gets when you defer upgrades.

A re-run port (e.g. Janet built at v1, re-targeted to the current spec) is the
natural max-drift anchor; pick one port per generation for the intermediate
points. The output is a maintenance-economics datapoint, not just a pass/fail.

### Measured curve (guile-sage, spec v5)
Holding paradigm constant (typed-FP: Rust/OCaml/Haskell) to isolate *drift* from
language difficulty, each upgraded to spec v5, gaps = beads:

| Port | baseline→v5 | distance | paradigm | gaps |
|------|-------------|----------|----------|------|
| sajure | v4→v5 | 1 | typed (reference) | 0 (doc-only) |
| Rust | v3→v5 | 2 | typed FP | 5 |
| OCaml | v2→v5 | 3 | typed FP | 5 |
| Haskell | v1→v5 | 4 | typed FP | 9 |
| Janet↺ | v1→v4 | 3 | **untyped** | 15 |

Three findings, none of them "drift is linear in distance":
1. **Paradigm dominates distance.** Typed `v1→v5` (9, dist 4) < untyped `v1→v4`
   (15, dist 3). A type system *pre-satisfies* the structural clarifications
   (value-type identity, exhaustiveness, deterministic encoding, CDATA round-trip),
   so a typed port pays roughly **half** the drift tax. Keep references typed.
2. **The typed curve is sub-linear** (5, 5, 9 across dist 2–4). Deferring four
   versions costs ~2× a single step, not 4×: structure amortizes, only behavior
   accrues.
3. **There is a stable "drift set"** — the same handful of *behavioral,
   not-type-enforceable* items recur in nearly every upgrade (Rust and OCaml
   converged on almost the same five): value-gated flags, the auto-compact
   threshold, missing-`name`→no-oracle error, config precedence, control-byte +
   byte-bounded errors, the pure/LLM compaction split. These are the spec items
   most worth making impossible to miss — the type system will not catch them.

Practical upshot: **stay-current is ~free (0–5 items/version); deferring is
sub-linearly worse if you're typed, painful if you're not.** This is the argument
for keeping a typed reference and upgrading every round.
