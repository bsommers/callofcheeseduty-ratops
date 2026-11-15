#!/bin/sh
# usage: tools/build.sh linux|windows|macos|all [--debug]
# Exports to build/<platform>/ (build -> a large disk). Templates: ~/.local/share/godot/export_templates/4.7.2.stable
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODE=--export-release; [ "${2:-}" = "--debug" ] && MODE=--export-debug
build_one() {
  case "$1" in
    linux)   P="Linux x86_64";   OUT="linux/kasekrieg-ratops.x86_64";;
    windows) P="Windows x86_64"; OUT="windows/KasekriegRatOps.exe";;
    macos)   P="macOS universal"; OUT="macos/KasekriegRatOps.zip";;
    *) echo "unknown platform $1" >&2; exit 2;;
  esac
  mkdir -p "$ROOT/build/$(dirname "$OUT")"
  rm -f "$ROOT/build/$(dirname "$OUT")"/*
  echo "== exporting $P"
  "$ROOT/tools/godot.sh" --headless --path "$ROOT/game" --import >/dev/null 2>&1 || true
  "$ROOT/tools/godot.sh" --headless --path "$ROOT/game" "$MODE" "$P" "$ROOT/build/$OUT" 2>&1 | tail -15
  [ -f "$ROOT/build/$OUT" ] || { echo "export FAILED: $OUT missing" >&2; exit 1; }
  ls -la "$ROOT/build/$(dirname "$OUT")"
}
case "${1:-}" in
  linux|windows|macos) build_one "$1";;
  all) build_one linux; build_one windows; build_one macos;;
  *) echo "usage: $0 linux|windows|macos|all [--debug]" >&2; exit 2;;
esac
