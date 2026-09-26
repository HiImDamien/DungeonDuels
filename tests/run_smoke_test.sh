#!/usr/bin/env bash
# Runs the end-to-end smoke test headless. Exit code = number of failed checks
# (or 1 if the test crashed / couldn't load, 124 if it hung).
#
#   tests/run_smoke_test.sh
#
# Set GODOT to your Godot binary if it isn't on your PATH, e.g.
#   GODOT=~/Desktop/Godot_mono.app/Contents/MacOS/Godot tests/run_smoke_test.sh
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
LIMIT=120  # seconds; the test itself gives up at 90

# Import first so newly added scripts/classes are registered.
"$GODOT" --headless --editor --quit --path . >/dev/null 2>&1

LOG="$(mktemp)"
"$GODOT" --headless --path . res://tests/smoke_test.tscn >"$LOG" 2>&1 &
PID=$!
for ((i = 0; i < LIMIT; i++)); do
	kill -0 "$PID" 2>/dev/null || break
	sleep 1
done
if kill -0 "$PID" 2>/dev/null; then
	kill "$PID"
	STATUS=124
	echo "Smoke test hung for ${LIMIT}s and was killed." >>"$LOG"
else
	wait "$PID"
	STATUS=$?
fi

grep -vE 'libhostfxr|dotnet|leaked at exit|still in use at exit|ObjectDB instances leaked|at: (cleanup|clear) ' "$LOG"
# A script error means the test didn't really run, even if Godot exited 0.
if [ "$STATUS" -eq 0 ] && ! grep -q '^[0-9]* checks, 0 failed' "$LOG"; then
	STATUS=1
fi
rm -f "$LOG"
exit "$STATUS"
