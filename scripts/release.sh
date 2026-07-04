#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="ProcessWatch"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DIST_DIR/$APP_NAME.app"
ZIP_PATH="$DIST_DIR/$APP_NAME-$VERSION-notarization.zip"
DMG_PATH="$DIST_DIR/$APP_NAME-$VERSION.dmg"
IDENTITY="${DEVELOPER_ID_APPLICATION:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Error: release builds require macOS." >&2
  exit 1
fi
if [[ -z "$IDENTITY" ]]; then
  cat >&2 <<'MESSAGE'
Error: DEVELOPER_ID_APPLICATION is not set.
Example:
  export DEVELOPER_ID_APPLICATION='Developer ID Application: Your Name (TEAMID)'
MESSAGE
  exit 1
fi
if [[ -z "$NOTARY_PROFILE" ]]; then
  cat >&2 <<'MESSAGE'
Error: NOTARY_PROFILE is not set.
Create a Keychain profile once, then export its name:
  xcrun notarytool store-credentials ProcessWatchNotary \
    --apple-id 'you@example.com' \
    --team-id 'TEAMID' \
    --password 'app-specific-password'
  export NOTARY_PROFILE='ProcessWatchNotary'
MESSAGE
  exit 1
fi

if command -v git >/dev/null 2>&1 && git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if [[ -n "$(git -C "$ROOT_DIR" status --porcelain)" && "${ALLOW_DIRTY_RELEASE:-0}" != "1" ]]; then
    echo "Error: git working tree is not clean. Set ALLOW_DIRTY_RELEASE=1 to override." >&2
    exit 1
  fi
fi

rm -rf "$DIST_DIR" "$ROOT_DIR/build"
mkdir -p "$DIST_DIR"

BUILD_NUMBER="${BUILD_NUMBER:-$(date +%Y%m%d%H%M)}" \
  "$ROOT_DIR/build.sh" \
  --clean \
  --release \
  --universal \
  --sign-identity "$IDENTITY"

/usr/bin/ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo "==> Submitting app archive for notarization"
xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"

DMG_PATH="$DMG_PATH" "$ROOT_DIR/scripts/package_dmg.sh" --skip-build
/usr/bin/codesign --force --timestamp --sign "$IDENTITY" "$DMG_PATH"

echo "==> Submitting DMG for notarization"
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"

/usr/sbin/spctl --assess --type execute --verbose=4 "$APP_PATH"
/usr/sbin/spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG_PATH"

rm -f "$ZIP_PATH"
/usr/bin/shasum -a 256 "$DMG_PATH" > "$DMG_PATH.sha256"
/usr/bin/shasum -a 256 "$APP_PATH/Contents/MacOS/$APP_NAME" "$DMG_PATH" > "$DIST_DIR/SHA256SUMS.txt"

cat <<MESSAGE

Release artifacts are ready:
  $APP_PATH
  $DMG_PATH
  $DIST_DIR/SHA256SUMS.txt

Upload the DMG and SHA256SUMS.txt to the GitHub Release for v$VERSION.
MESSAGE
