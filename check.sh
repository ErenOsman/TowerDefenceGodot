#!/bin/bash
# Parse-check every script in the project (serialised across agents with a lock, since Godot writes .godot/).
#   ./check.sh            → CHECK OK / CHECK FAIL lines, plus every SCRIPT ERROR Godot printed
cd "$(dirname "$0")"
flock /home/ubuntu/godot/.td.lock timeout 300 godot --headless --path . --import >/dev/null 2>&1
flock /home/ubuntu/godot/.td.lock timeout 300 godot --headless --path . -s tools/check.gd 2>&1 | grep -E "CHECK|SCRIPT ERROR|Parse Error|ERROR: |at: |  at " | grep -v "RID allocations\|resources still in use\|ALSA\|Pages in use" | head -200
