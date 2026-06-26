---
name: guile-consistency-audit
description: Audit gmake/build/test/Makefile consistency across a family of sibling repos (guile-* or any gmake project) by driving an interactive `claude` session per project in tmux. Use when checking many sibling repos for build-toolchain drift (e.g. after a userland/toolchain change), or to enforce a shared Makefile convention. Read-only by default.
---

# guile-consistency-audit

Audit a directory of sibling projects for build consistency. For each project it
runs an **interactive `claude`** (not `claude -p`) in its own tmux session,
asks it to run `gmake help` + the build/test targets, and report drift. Output
is one concise report per project; nothing is modified.

## When to use
- A family of sibling repos (e.g. `~/ghq/github.com/<org>/guile-*`) should share
  a build convention (`gmake build/check/help`, one runtime) and you want to find
  the ones that drifted.
- After a toolchain/userland change (e.g. only `guile3` installed, no `guile`).

## How to run
```sh
# audit every guile-* sibling under the current parent dir
./drive.sh ~/ghq/github.com/dsp-dr/guile-*
# or a explicit list
./drive.sh ~/ghq/github.com/dsp-dr/{guile-foo,guile-bar}
```
`drive.sh` (next to this file) launches interactive claude per project with a
**temporary** `.claude/settings.local.json` that bypasses permission prompts
(so the read-only probe runs uninterrupted), captures the report, then **removes**
the temp settings (backing up any pre-existing one). No `-p`, no subshell-wraps,
no permanent change to the audited repos.

## What it checks (the consistency checklist)
1. **Runtime**: hardcoded `guile`/`#!/usr/bin/env guile` vs the installed
   `guile3` — auto-detect (`command -v guile3 || guile`, `>=3` gate) is correct.
2. **Masked failures** — the silent-green traps:
   - shell `|| true`/`|| echo`, recipe loops with no exit tracking, no `pipefail`.
   - **SRFI-64 default runner exits 0 even on a failing `test-assert`** — only
     crashes propagate. Fix: a custom runner that `(exit 1)` when fail-count > 0.
3. **POSIX-portable Makefile** — `?`/`*?` lazy quantifier or a `\` inside a
   quoted string in the `help`/`check` grep breaks on FreeBSD `ugrep`; masked by
   an un-`pipefail`'d pipe so `gmake` still exits 0.
4. **Default goal** — `all: help` (or `check`) makes a bare `gmake` green while
   building nothing.
5. **Convention targets** — `help` (self-documenting), `build`, and `check`
   (alias `test` if needed so `gmake check` always works).
6. **Compile correctness** — compile rule carries `-L src` and orders deps.
7. **Sandbox** — `install` stays within `$HOME` (XDG), never `/usr/local`.

## Recommended Makefile standard (the target state)
```makefile
GUILE ?= $(shell command -v guile3 2>/dev/null || command -v guile)
GUILD ?= $(shell command -v guild3 2>/dev/null || command -v guild)
.DEFAULT_GOAL := help
help:   ## list targets (awk-only, no grep ? / *? / \)
	@awk -F':.*##' '/^[a-zA-Z0-9_-]+:.*##/{printf "  %-14s %s\n",$$1,$$2}' $(MAKEFILE_LIST)
build:  ## compile modules (guild compile -L src ...)
check: test   ## convention alias
test:   ## run suite via a custom SRFI-64 runner that (exit 1) on failures
```

## Gotchas (learned the hard way)
- Drive interactive claude via tmux `send-keys`; the trailing Enter after a long
  prompt can race — send the text, sleep, then send Enter separately to submit.
- NEVER blind-send approval keystrokes on a timer: a stray key while a tool runs
  becomes a queued message that **interrupts** the tool. Either pre-bypass
  permissions (drive.sh does) or only send approvals when "Do you want to
  proceed?" is on screen.
- A first-run "fullscreen renderer?" dialog may appear once per machine — dismiss it.
