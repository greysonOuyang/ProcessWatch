#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="ProcessWatch"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
APP_PATH="$ROOT_DIR/dist/$APP_NAME.app"
DMG_PATH="${DMG_PATH:-$ROOT_DIR/dist/$APP_NAME-$VERSION.dmg}"
STAGING="$ROOT_DIR/build/dmg-root"
SKIP_BUILD=0
UNIVERSAL=0

usage() {
  cat <<'USAGE'
Usage: ./scripts/package_dmg.sh [options]

Options:
  --skip-build    Package the existing dist/ProcessWatch.app
  --universal     Build a universal app before packaging
  -h, --help      Show help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-build) SKIP_BUILD=1 ;;
    --universal) UNIVERSAL=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if [[ "$SKIP_BUILD" -eq 0 ]]; then
  args=(--release)
  [[ "$UNIVERSAL" -eq 1 ]] && args+=(--universal)
  "$ROOT_DIR/build.sh" "${args[@]}"
fi
[[ -d "$APP_PATH" ]] || { echo "Missing $APP_PATH" >&2; exit 1; }

rm -rf "$STAGING" "$DMG_PATH"
mkdir -p "$STAGING"
/usr/bin/ditto "$APP_PATH" "$STAGING/$APP_NAME.app"
ln -s /Applications "$STAGING/Applications"
cp "$ROOT_DIR/README.md" "$STAGING/README.txt"

/usr/bin/hdiutil create \
  -volname "$APP_NAME $VERSION" \
  -srcfolder "$STAGING" \
  -ov \
  -format UDZO \
  "$DMG_PATH"
rm -rf "$STAGING"

/usr/bin/shasum -a 256 "$DMG_PATH" > "$DMG_PATH.sha256"
echo "DMG created: $DMG_PATH"
echo "Checksum: $DMG_PATH.sha256"
