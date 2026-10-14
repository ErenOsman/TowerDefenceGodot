#!/bin/bash
# Run the test suite:  ./test.sh [--filter name]
# Prints FAIL lines, SCRIPT ERROR lines and the summary. Exit code 1 on failures.
# On the server, when the resident headless Godot daemon is alive, the suite runs in it (no start-up, no import,
# no lock; see /home/ubuntu/godot/README-daemon.md). TD_NO_DAEMON=1 forces the direct run below.
# GODOT=<path to executable> overrides the binary (default: `godot` on PATH; see godot.local.sh); it also means
# a direct run.
cd "$(dirname "$0")"
FILTER="RID allocations|resources still in use|ALSA|Pages in use|^$|Godot Engine v"
JOBS=/home/ubuntu/godot/jobs.sh
if [ -z "${TD_NO_DAEMON:-}" ] && [ -z "${GODOT:-}" ] && [ ! -f godot.local.sh ] && [ -x "$JOBS" ] && "$JOBS" --alive; then
  "$JOBS" test "$@" 2>&1 | grep -vE "$FILTER" | head -400
  exit ${PIPESTATUS[0]}
fi
[ -f godot.local.sh ] && source godot.local.sh
GODOT="${GODOT:-godot}"
if command -v flock >/dev/null 2>&1; then LOCK="flock /home/ubuntu/godot/.td.lock"; else LOCK=""; fi
$LOCK timeout 300 "$GODOT" --headless --path . --import >/dev/null 2>&1
$LOCK timeout 600 "$GODOT" --headless --path . -s tests/run.gd -- "$@" 2>&1 \
  | grep -vE "$FILTER" | head -400
exit ${PIPESTATUS[0]}
