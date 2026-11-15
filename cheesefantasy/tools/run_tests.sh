#!/bin/sh
# Run the headless test suite (game/tests/test_*.gd). usage: tools/run_tests.sh [filter]
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
[ -d "$ROOT/game/.godot" ] || "$ROOT/tools/godot.sh" --headless --path "$ROOT/game" --import >/dev/null 2>&1 || true
exec "$ROOT/tools/godot.sh" --headless --path "$ROOT/game" --script res://tests/run_all.gd -- "$@"
