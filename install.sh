#!/usr/bin/env bash
# install.sh — symlink every skills/* into ~/.claude/skills/ (idempotent).
set -euo pipefail
DEST="${HOME}/.claude/skills"; mkdir -p "$DEST"
SRC="$(cd "$(dirname "$0")/skills" && pwd)"
for d in "$SRC"/*/; do
  name="$(basename "$d")"
  ln -sfn "$d" "$DEST/$name"
  echo "linked: $DEST/$name -> $d"
done
