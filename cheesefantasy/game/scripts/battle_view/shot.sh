#!/bin/sh
# Battle screenshot harness (battle-presentation). Renders scenes/battle/battle_shot.tscn on the real GPU inside a
# private Xvfb (never the user's display). usage: shot.sh --out=/path/prefix [--mode=..] [--times=..] [...user args]
set -eu
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
W=1920; H=1080
FIFO="$(mktemp -u)"; mkfifo "$FIFO"
Xvfb -displayfd 3 -screen 0 "${W}x${H}x24" -nolisten tcp -noreset 3>"$FIFO" >/dev/null 2>&1 &
XPID=$!
DNUM="$(head -n1 "$FIFO")"; rm -f "$FIFO"
trap 'kill $XPID 2>/dev/null || true' EXIT
[ -n "$DNUM" ] || { echo "Xvfb failed" >&2; exit 1; }
env -u WAYLAND_DISPLAY MESA_VK_WSI_DEBUG=sw DISPLAY=":$DNUM" XDG_SESSION_TYPE=x11 timeout 120 "$ROOT/tools/godot.sh" \
  --path "$ROOT/game" --display-driver x11 --rendering-driver vulkan --resolution "${W}x${H}" --position 0,0 \
  --gpu-index "${SHOT_GPU:-0}" res://scenes/battle/battle_shot.tscn -- "$@"
