#!/usr/bin/env bash
# drive.sh — audit gmake/build/test consistency across projects by running an
# interactive `claude` in tmux per project. Read-only (claude told not to modify).
# Usage: ./drive.sh <project-dir> [project-dir ...]
#        ./drive.sh ~/ghq/github.com/dsp-dr/guile-*
# Per project: temporarily bypass permission prompts via .claude/settings.local.json
# (backed up + removed after), so the probe runs uninterrupted. No `-p`.
set -uo pipefail
[ "$#" -ge 1 ] || { echo "usage: $0 <project-dir> [more...]"; exit 2; }
TS="audit$$"
PROMPT='Concise report, DO NOT modify files. Run gmake help (or list targets), then default build, then the test target, for THIS project. State: build status, test status, and Makefile inconsistencies (guile vs guile3, missing check/help, masked failures incl SRFI-64 default-runner exit-0-on-fail, non-POSIX grep, default=help). If no Makefile, say how it builds.'

audit_one() {
  local DIR="$1" name; name="$(basename "$DIR")"
  [ -d "$DIR" ] || { echo "== $name: (missing) =="; return; }
  local CD="$DIR/.claude" SL BK=""
  mkdir -p "$CD"; SL="$CD/settings.local.json"
  [ -f "$SL" ] && { BK="$SL.auditbak"; mv "$SL" "$BK"; }
  printf '{"permissions":{"defaultMode":"bypassPermissions"},"skipDangerousModePermissionPrompt":true}\n' > "$SL"
  tmux kill-session -t "$TS" 2>/dev/null
  tmux new-session -d -s "$TS" -x 210 -y 50 -c "$DIR"
  tmux send-keys -t "$TS" 'claude' Enter; sleep 11
  tmux capture-pane -t "$TS" -p | grep -qiE "fullscreen renderer|bypass perm|dangerous" && { tmux send-keys -t "$TS" Enter; sleep 2; }
  tmux send-keys -t "$TS" "$PROMPT"; sleep 2; tmux send-keys -t "$TS" Enter
  sleep 70
  echo "================ $name ================"
  tmux capture-pane -t "$TS" -p -S -170 | sed '/^[[:space:]]*$/d' \
    | grep -vE "▐▛|▝▜|▘▘|Welcome back|What.s new|release-notes|getting started|OpenTelemetry|^╭───|^╰───|^│ +│|──────|for shortcuts|for agents|Tip:" | tail -14
  rm -f "$SL"; [ -n "$BK" ] && mv "$BK" "$SL"; rmdir "$CD" 2>/dev/null
  tmux kill-session -t "$TS" 2>/dev/null
}

for d in "$@"; do audit_one "$d"; done
