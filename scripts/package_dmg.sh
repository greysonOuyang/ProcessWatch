#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="ProcessWatch"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
APP_PATH="$DIST_DIR/$APP_NAME.app"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"
STAGING_DIR="$ROOT_DIR/build/dmg-root"
SKIP_BUILD=0

usage() {
  cat <<'USAGE'
Usage: ./scripts/package_dmg.sh [options]

Options:
  --skip-build  Package the existing dist/ProcessWatch.app
  --debug       Build Debug before packaging
  --release     Build Release before packaging (default)
  -h, --help    Show this help
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
  echo "Error: DMG packaging requires macOS." >&2
  exit 1
fi

if ! command -v hdiutil >/dev/null 2>&1; then
  echo "Error: hdiutil was not found." >&2
  exit 1
fi

if [[ "$SKIP_BUILD" -eq 0 ]]; then
  "$ROOT_DIR/scripts/build_app.sh" "${BUILD_ARGS[@]}"
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "Error: application not found: $APP_PATH" >&2
  echo "Run ./scripts/build_app.sh first." >&2
  exit 1
fi

echo "==> Preparing DMG contents"
rm -rf "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$STAGING_DIR"
ditto "$APP_PATH" "$STAGING_DIR/$APP_NAME.app"
ln -s /Applications "$STAGING_DIR/Applications"

echo "==> Creating $DMG_PATH"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

rm -rf "$STAGING_DIR"
printf '\nDMG created:\n  %s\n' "$DMG_PATH"
