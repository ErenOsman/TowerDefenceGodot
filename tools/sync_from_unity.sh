#!/bin/bash
# Pull what the Godot build shares with the Unity repo (the single source of truth for content and design):
#   ./tools/sync_from_unity.sh [path to the Unity repo, default ~/game]
# - Content/*.json          → data/content/   (towers, abilities, levels, statuses, sequences…; the sim reads these)
# - Docs/Design/*.md        → docs/design/    (design docs incl. "UI Design Rules — Design.md"; read-only copies)
# - Docs/Decisions.md, Docs/Glossary.md → docs/
# Then re-checks the simulation against the C# golden logs when they exist (~/godot/golden), so a content change
# that alters play shows up at once. Godot-only notes live in docs/GODOT-NOTES.md (never overwritten).
set -e
cd "$(dirname "$0")/.."
UNITY="${1:-$HOME/game}"
[ -d "$UNITY/Content" ] || { echo "no Unity repo at $UNITY"; exit 1; }
mkdir -p data/content docs/design
changed=0
for f in "$UNITY"/Content/*.json; do
  b="$(basename "$f")"
  if ! cmp -s "$f" "data/content/$b"; then cp "$f" "data/content/$b"; echo "content: $b"; changed=1; fi
done
for f in "$UNITY"/Docs/Design/*.md "$UNITY"/Docs/Decisions.md "$UNITY"/Docs/Glossary.md; do
  [ -f "$f" ] || continue
  case "$f" in */Docs/Design/*) dst="docs/design/$(basename "$f")";; *) dst="docs/$(basename "$f")";; esac
  if ! cmp -s "$f" "$dst"; then cp "$f" "$dst"; echo "doc: $(basename "$f")"; fi
done
echo "synced from $UNITY ($(git -C "$UNITY" log -1 --format='%h %ad' --date=short 2>/dev/null))"
if [ "$changed" = 1 ] && [ -d "$HOME/godot/golden" ] && command -v godot >/dev/null; then
  echo "content changed: re-running the golden comparison (differences are expected when rules/content changed on purpose)"
  flock /home/ubuntu/godot/.td.lock timeout 900 godot --headless --path . -s tools/golden.gd 2>&1 | grep -E "^[a-z0-9-]+:|----" || true
fi
