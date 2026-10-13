#!/bin/bash
# Two headless Godot clients play a co-op match through the live relay (lockstep end-to-end test).
#   ./tools/coop_two.sh [level id] [rounds] [relay url]
# Prints both bots' logs; exit 0 when both finished without desync/refusal.
cd "$(dirname "$0")/.."
LEVEL="${1:-chapter1-1}"; ROUNDS="${2:-6}"; URL="${3:-ws://127.0.0.1/ws/relay}"
ROOM="bots-$$"
OUT=/tmp/claude-1001/-home-ubuntu-claude/6782c35d-6c38-58ad-9ee3-e8ad88840f64/scratchpad/coop
mkdir -p "$OUT"
timeout 300 godot --headless --path . -s tools/coop_bot.gd -- host Host "$ROOM" "$LEVEL" "$ROUNDS" "$URL" > "$OUT/host.log" 2>&1 &
H=$!
sleep 4
timeout 300 godot --headless --path . -s tools/coop_bot.gd -- guest Guest "$ROOM" "$LEVEL" "$ROUNDS" "$URL" > "$OUT/guest.log" 2>&1 &
G=$!
wait $H; HC=$?
wait $G; GC=$?
grep -E "^BOT" "$OUT/host.log" "$OUT/guest.log"
echo "host exit $HC, guest exit $GC"
[ "$HC" = 0 ] && [ "$GC" = 0 ]
