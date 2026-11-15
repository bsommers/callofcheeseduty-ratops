#!/bin/sh
# KÄSEKRIEG: RAT OPS installer for Linux (x86_64) and macOS.
#
#   curl -fsSL https://bsommers.github.io/callofcheeseduty-ratops/install.sh | sh
#   curl -fsSL https://bsommers.github.io/callofcheeseduty-ratops/install.sh | sh -s -- --uninstall
#
# Downloads the latest GitHub Release asset, verifies its SHA-256 against the
# release's SHA256SUMS, and installs per-user. No sudo is ever used.
#   Linux: ~/.local/share/kasekrieg-ratops, launcher ~/.local/bin/kasekrieg-ratops
#   macOS: ~/Applications/<app>.app (copied out of the .dmg)
#
# Options: --dry-run   show what would happen, change nothing (still reads SHA256SUMS)
#          --uninstall remove everything this script installed
#          -h|--help
# Env:     RATOPS_BASE_URL  override the download base (testing / mirrors)
set -eu

REPO="bsommers/callofcheeseduty-ratops"
BASE="${RATOPS_BASE_URL:-https://github.com/$REPO/releases/latest/download}"
APP_NAME="kasekrieg-ratops"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
DEST="$DATA_HOME/$APP_NAME"
BIN_DIR="$HOME/.local/bin"
BIN="$BIN_DIR/$APP_NAME"
DESKTOP="$DATA_HOME/applications/$APP_NAME.desktop"
MAC_APP_DIR="$HOME/Applications"
MAC_APP="$MAC_APP_DIR/KÄSEKRIEG- RAT OPS.app"

DRY=0
UNINSTALL=0
TMP=""

say() { printf '%s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }
# run CMD... unless --dry-run, in which case just print it
run() {
  if [ "$DRY" -eq 1 ]; then printf '[dry-run] %s\n' "$*"; else "$@"; fi
}
cleanup() { [ -n "$TMP" ] && rm -rf "$TMP"; return 0; }
trap cleanup EXIT INT TERM

usage() { sed -n '2,17p' "$0" 2>/dev/null | sed 's/^# \{0,1\}//' || true; }

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY=1 ;;
    --uninstall) UNINSTALL=1 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $arg (try --help)" ;;
  esac
done

OS="$(uname -s)"
ARCH="$(uname -m)"

if [ "$UNINSTALL" -eq 1 ]; then
  case "$OS" in
    Linux) run rm -rf "$DEST"; run rm -f "$BIN" "$DESKTOP" ;;
    Darwin) run rm -rf "$MAC_APP" ;;
    *) die "unsupported OS: $OS" ;;
  esac
  say "Uninstalled. Save games live in your Godot user data folder and were kept."
  exit 0
fi

case "$OS" in
  Linux)
    case "$ARCH" in
      x86_64|amd64) PATTERN='linux-x86_64\.tar\.gz$' ;;
      *) die "no Linux build for $ARCH (only x86_64)" ;;
    esac ;;
  Darwin) PATTERN='macos\.dmg$' ;;
  *) die "unsupported OS: $OS. On Windows use install.ps1." ;;
esac

# Pick a downloader and a sha256 tool.
if command -v curl >/dev/null 2>&1; then
  fetch() { curl -fL --proto '=https,file' --tlsv1.2 -o "$2" "$1"; }
  fetch_quiet() { curl -fsSL --proto '=https,file' --tlsv1.2 -o "$2" "$1"; }
elif command -v wget >/dev/null 2>&1; then
  fetch() { wget -O "$2" "$1"; }
  fetch_quiet() { wget -q -O "$2" "$1"; }
else
  die "need curl or wget"
fi
if command -v sha256sum >/dev/null 2>&1; then
  sha_of() { sha256sum "$1" | cut -d' ' -f1; }
elif command -v shasum >/dev/null 2>&1; then
  sha_of() { shasum -a 256 "$1" | cut -d' ' -f1; }
else
  die "need sha256sum or shasum"
fi

TMP="$(mktemp -d)"

say "Fetching checksum list from $BASE/SHA256SUMS"
fetch_quiet "$BASE/SHA256SUMS" "$TMP/SHA256SUMS" || die "could not download SHA256SUMS (has a GitHub Release been published?)"

# SHA256SUMS lines look like "<hash>  <file>" (file may carry a leading '*').
LINE="$(grep -E "$PATTERN" "$TMP/SHA256SUMS" | grep -v -- '-install\.sh' | head -n 1 || true)"
[ -n "$LINE" ] || die "no matching asset for $OS/$ARCH in SHA256SUMS"
WANT="$(printf '%s' "$LINE" | awk '{print $1}')"
FILE="$(printf '%s' "$LINE" | awk '{print $2}' | sed 's/^\*//')"
case "$FILE" in */*|*..*) die "suspicious file name in SHA256SUMS: $FILE" ;; esac

say "Asset:    $FILE"
say "Expected: $WANT"
say "Download: $BASE/$FILE (large file, roughly 180-220 MB)"

if [ "$DRY" -eq 1 ]; then
  say "[dry-run] would download, verify sha256, then install:"
  case "$OS" in
    Linux)
      say "[dry-run]   extract to $DEST"
      say "[dry-run]   symlink  $BIN"
      say "[dry-run]   write    $DESKTOP" ;;
    Darwin)
      say "[dry-run]   mount the dmg, copy the .app to $MAC_APP_DIR, clear quarantine flag" ;;
  esac
  say "[dry-run] nothing was changed."
  exit 0
fi

fetch "$BASE/$FILE" "$TMP/$FILE"
GOT="$(sha_of "$TMP/$FILE")"
if [ "$GOT" != "$WANT" ]; then
  die "checksum mismatch for $FILE (expected $WANT, got $GOT); nothing installed"
fi
say "Checksum OK."

case "$OS" in
  Linux)
    mkdir -p "$DEST" "$BIN_DIR" "$(dirname "$DESKTOP")"
    tar -xzf "$TMP/$FILE" -C "$DEST" --strip-components=1
    ln -sf "$DEST/$APP_NAME.sh" "$BIN"
    printf '[Desktop Entry]\nType=Application\nName=KÄSEKRIEG: RAT OPS\nExec=%s/%s.sh\nIcon=%s/%s.png\nTerminal=false\nCategories=Game;ActionGame;\n' \
      "$DEST" "$APP_NAME" "$DEST" "$APP_NAME" > "$DESKTOP"
    say "Installed to $DEST"
    case ":$PATH:" in
      *":$BIN_DIR:"*) say "Run it with:  $APP_NAME" ;;
      *) say "Run it with:  $BIN   (add $BIN_DIR to your PATH to type just '$APP_NAME')" ;;
    esac
    say "Uninstall:    curl -fsSL https://bsommers.github.io/$(basename "$REPO")/install.sh | sh -s -- --uninstall"
    ;;
  Darwin)
    command -v hdiutil >/dev/null 2>&1 || die "hdiutil not found"
    MNT="$TMP/mnt"
    mkdir -p "$MNT" "$MAC_APP_DIR"
    hdiutil attach -nobrowse -readonly -mountpoint "$MNT" "$TMP/$FILE" >/dev/null
    APP_SRC="$(find "$MNT" -maxdepth 1 -name '*.app' | head -n 1)"
    if [ -z "$APP_SRC" ]; then hdiutil detach "$MNT" >/dev/null 2>&1 || true; die "no .app inside the dmg"; fi
    rm -rf "$MAC_APP"
    cp -R "$APP_SRC" "$MAC_APP"
    hdiutil detach "$MNT" >/dev/null 2>&1 || true
    # The build is unsigned; clear Gatekeeper's quarantine flag so it opens.
    xattr -dr com.apple.quarantine "$MAC_APP" 2>/dev/null || true
    say "Installed to $MAC_APP"
    say "Run it with:  open \"$MAC_APP\""
    ;;
esac
