#!/bin/bash
# Run the test suite:  ./test.sh [--filter name]
# Prints FAIL lines, SCRIPT ERROR lines and the summary. Exit code 1 on failures.
cd "$(dirname "$0")"
flock /home/ubuntu/godot/.td.lock timeout 300 godot --headless --path . --import >/dev/null 2>&1
flock /home/ubuntu/godot/.td.lock timeout 600 godot --headless --path . -s tests/run.gd -- "$@" 2>&1 \
  | grep -vE "RID allocations|resources still in use|ALSA|Pages in use|^$|Godot Engine v" | head -400
exit ${PIPESTATUS[0]}
