#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="ProcessWatch"
SOURCE_APP="$ROOT_DIR/dist/$APP_NAME.app"
TARGET_ROOT="$HOME/Applications"
SKIP_BUILD=0
SYSTEM_INSTALL=0

usage() {
  cat <<'USAGE'
Usage: ./scripts/install_app.sh [options]

Options:
  --skip-build    Install the existing dist/ProcessWatch.app
  --system        Install to /Applications instead of ~/Applications
  -h, --help      Show help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-build) SKIP_BUILD=1 ;;
    --system) SYSTEM_INSTALL=1; TARGET_ROOT="/Applications" ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if [[ "$SKIP_BUILD" -eq 0 ]]; then
  "$ROOT_DIR/build.sh" --release
fi
[[ -d "$SOURCE_APP" ]] || { echo "Missing $SOURCE_APP" >&2; exit 1; }

TARGET_APP="$TARGET_ROOT/$APP_NAME.app"
/usr/bin/osascript -e 'tell application "ProcessWatch" to quit' >/dev/null 2>&1 || true
sleep 1

if [[ "$SYSTEM_INSTALL" -eq 1 ]]; then
  sudo /bin/rm -rf "$TARGET_APP"
  sudo /usr/bin/ditto "$SOURCE_APP" "$TARGET_APP"
else
  mkdir -p "$TARGET_ROOT"
  rm -rf "$TARGET_APP"
  /usr/bin/ditto "$SOURCE_APP" "$TARGET_APP"
fi

/usr/bin/open "$TARGET_APP"
echo "Installed: $TARGET_APP"
echo "Note: this script does not remove Gatekeeper quarantine attributes."
