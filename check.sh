#!/bin/bash
# Parse-check every script in the project (serialised across agents with a lock, since Godot writes .godot/).
#   ./check.sh            → CHECK OK / CHECK FAIL lines, plus every SCRIPT ERROR Godot printed
# On the server, when the resident headless Godot daemon is alive, the check runs in it (changed scripts are
# recompiled in place; no start-up, no import, no lock; see /home/ubuntu/godot/README-daemon.md).
# TD_NO_DAEMON=1 forces the direct run below.
# GODOT=<path to executable> overrides the binary (default: `godot` on PATH; see godot.local.sh); it also means
# a direct run.
cd "$(dirname "$0")"
JOBS=/home/ubuntu/godot/jobs.sh
if [ -z "${TD_NO_DAEMON:-}" ] && [ -z "${GODOT:-}" ] && [ ! -f godot.local.sh ] && [ -x "$JOBS" ] && "$JOBS" --alive; then
  "$JOBS" check 2>&1 | grep -E "CHECK|SCRIPT ERROR|Parse Error|ERROR: |at: |  at " | grep -v "RID allocations\|resources still in use\|ALSA\|Pages in use" | head -200
  exit $?
fi
[ -f godot.local.sh ] && source godot.local.sh
GODOT="${GODOT:-godot}"
if command -v flock >/dev/null 2>&1; then LOCK="flock /home/ubuntu/godot/.td.lock"; else LOCK=""; fi
$LOCK timeout 300 "$GODOT" --headless --path . --import >/dev/null 2>&1
$LOCK timeout 300 "$GODOT" --headless --path . -s tools/check.gd 2>&1 | grep -E "CHECK|SCRIPT ERROR|Parse Error|ERROR: |at: |  at " | grep -v "RID allocations\|resources still in use\|ALSA\|Pages in use" | head -200
