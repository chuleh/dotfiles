#!/bin/bash
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
DEST="${CLAUDE_HOME:-$HOME/.claude}"

mkdir -p "$DEST/agents" "$DEST/commands" "$DEST/hooks" "$DEST/bin" "$DEST/skills"

cp -R "$SRC/agents/." "$DEST/agents/"
cp "$SRC/commands/"*.md "$DEST/commands/"
cp -R "$SRC/hooks/." "$DEST/hooks/"
cp -R "$SRC/bin/." "$DEST/bin/"

find "$SRC/skills" -name SKILL.md -print0 | while IFS= read -r -d '' f; do
  dir="$(dirname "$f")"
  name="$(basename "$dir")"
  rm -rf "$DEST/skills/$name"
  cp -R "$dir" "$DEST/skills/$name"
  echo "skill: $name"
done

if [ -e "$DEST/CLAUDE.md" ]; then
  echo "note: $DEST/CLAUDE.md exists — merge $SRC/CLAUDE.md manually"
else
  cp "$SRC/CLAUDE.md" "$DEST/CLAUDE.md"
  echo "installed: CLAUDE.md"
fi

echo "note: merge settings.example.json into $DEST/settings.json manually"
echo "done -> $DEST (restart or /clear to load)"
