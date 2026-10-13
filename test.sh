#!/bin/bash
# Run the test suite:  ./test.sh [--filter name]
# Prints FAIL lines, SCRIPT ERROR lines and the summary. Exit code 1 on failures.
# GODOT=<path to executable> overrides the binary (default: `godot` on PATH; see godot.local.sh).
cd "$(dirname "$0")"
[ -f godot.local.sh ] && source godot.local.sh
GODOT="${GODOT:-godot}"
if command -v flock >/dev/null 2>&1; then LOCK="flock /home/ubuntu/godot/.td.lock"; else LOCK=""; fi
$LOCK timeout 300 "$GODOT" --headless --path . --import >/dev/null 2>&1
$LOCK timeout 600 "$GODOT" --headless --path . -s tests/run.gd -- "$@" 2>&1 \
  | grep -vE "RID allocations|resources still in use|ALSA|Pages in use|^$|Godot Engine v" | head -400
exit ${PIPESTATUS[0]}
