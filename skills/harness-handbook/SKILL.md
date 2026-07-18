---
name: harness-handbook
description: Generate and maintain a behavior→code map ("Behavior Handbook") for an agent harness or any behavior-heavy codebase, so a single behavior (permission check, taint wrap, retry) can be located across the many files that implement it. Use before a change (to find every site it must touch), to audit guardrails, or as the code-anchored companion to a spec. Method from the Harness Handbook (arXiv:2607.13285): facts → map → handbook, three levels, "prose explains; facts anchor".
---

# harness-handbook

An agent harness's behavior is *implicit and scattered*: "ask before deleting a
file" lives across a prompt, a tool wrapper, a permission rule, state, a sandbox
path, and a fallback. A **Behavior Handbook** re-organizes the code **by behavior
instead of by file**, so you can find every site a behavior touches — and every
site a change must touch — without untargeted repo search. (Ref: Wang et al.,
*Harness Handbook*, arXiv:2607.13285.)

It is the **companion to a spec**: the spec says *WHAT* each boundary is; the
handbook says *WHERE and HOW* it's implemented. Pair this with
`spec-driven-port-grind` (spec = contract; handbook = code map of the reference).

## When to use
- Before editing a cross-cutting behavior — to localize ALL its sites (the common
  failure is missing a prompt, a permission rule, or a fallback path).
- To audit a guardrail: trace the actual execution path (permissions, confirmation,
  sandbox, taint) including the unusual routes that might bypass it.
- To onboard a human or a change-agent to a harness fast.
- Keep it current as the code evolves — a stale map is worse than none.

## The three levels
- **L1 — System overview:** the end-to-end request flow through the harness
  (entrypoint → provider/model call → tool-call loop → result), for every path
  (e.g. interactive loop AND server/RPC path). Anchor the entrypoints.
- **L2 — Behavior units:** decompose into coherent units (provider error-norm,
  permission/path-containment, MCP client, MCP server, taint, retry, compaction,
  agent loop, sessions). For each: responsibility (1–2 lines), inputs/outputs,
  dependencies on other units, and the anchoring functions.
- **L3 — Behavior-unit detail** (for the priority/guardrail units): triggers,
  state changes, execution path (normal + the notable exception/edge route),
  and code evidence. This is where audits happen.

## The iron rule: prose explains; facts anchor
Every non-trivial claim cites a real `file:line` — **verified by opening the file**,
not guessed. A handbook whose anchors drift is a liability. Prefer citing the
function + the exact line of the decision (the `if`, the `error`, the `escape`),
not just the file.

## Generation pipeline (facts → map → handbook)
1. **Extract facts:** read the spec (it names the behaviors) + the source; build a
   mental program graph (entrypoints, the dispatch/loop, tool exec, state
   reads/writes, permission/sandbox boundaries).
2. **Organize by behavior:** map functions to execution stages / behavior units;
   refine with a proposer→reviewer pass (does each unit have one responsibility,
   clear I/O, honest dependencies?).
3. **Synthesize:** render tight prose anchored to the extracted facts. Cross-link
   to the spec sections.
4. **Reconcile:** where a spec behavior has no code site (or vice versa), that's a
   **spec/impl gap** — flag it (a bead), don't paper over it. Surfacing these is a
   primary payoff.

## Behavior-Guided Progressive Disclosure (BGPD) — using the handbook
To localize a change: start from the behavior *question* → L1 (which path) → L2
(which unit) → L3 (which sites + edge routes) → code. This replaces grep-and-hope
and is what lets a change-agent produce a tight, complete edit plan.

## Keep humans in the loop
The handbook makes behavior **auditable and reviewable** — it's the substrate for
human review of an otherwise opaque harness. When an autonomous loop proposes a
change, the handbook is how a human verifies the proposal touches the right sites
and no bypass route.

## Worked example (guile-sage, 2026)
`docs/HANDBOOK.org`: L1 for both paths (agent loop + MCP server), 9 L2 units
mapped to spec §2–§8, L3 for the three §12 guardrail units (permission/safe-path,
MCP no-oracle, taint), ~90 verified `file:line` anchors. Generating it surfaced a
real spec/impl gap (the §15.7 round-trip inverse exists only in the test suite,
not in-source) — exactly the kind of finding the map is meant to expose.
