#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="ProcessWatch"
SOURCE_APP="${SOURCE_APP:-$ROOT_DIR/dist/$APP_NAME.app}"
INSTALL_DIR="${INSTALL_DIR:-/Applications}"
TARGET_APP="$INSTALL_DIR/$APP_NAME.app"
SKIP_BUILD=0

usage() {
  cat <<'USAGE'
Usage: ./scripts/install_app.sh [options]

Options:
  --skip-build  Install the existing dist/ProcessWatch.app
  --debug       Build Debug before installation
  --release     Build Release before installation (default)
  -h, --help    Show this help

Environment variables:
  INSTALL_DIR   Installation directory, defaults to /Applications
  SOURCE_APP    Existing .app path to install
USAGE
}

BUILD_ARGS=(--release)
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-build) SKIP_BUILD=1 ;;
    --debug) BUILD_ARGS=(--debug) ;;
    --release) BUILD_ARGS=(--release) ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Error: installation requires macOS." >&2
  exit 1
fi

if [[ "$SKIP_BUILD" -eq 0 ]]; then
  "$ROOT_DIR/scripts/build_app.sh" "${BUILD_ARGS[@]}"
fi

if [[ ! -d "$SOURCE_APP" ]]; then
  echo "Error: application not found: $SOURCE_APP" >&2
  exit 1
fi

mkdir -p "$INSTALL_DIR"

# Stop a running copy before replacing the application bundle.
osascript -e "tell application \"$APP_NAME\" to quit" >/dev/null 2>&1 || true
sleep 1

echo "==> Installing to $TARGET_APP"
rm -rf "$TARGET_APP"
ditto "$SOURCE_APP" "$TARGET_APP"
xattr -dr com.apple.quarantine "$TARGET_APP" 2>/dev/null || true

echo "==> Launching $APP_NAME"
open "$TARGET_APP"
printf '\nInstalled:\n  %s\n' "$TARGET_APP"
