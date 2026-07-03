#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/ProcessWatch.xcodeproj"
SOURCE_DIR="$ROOT_DIR/Sources"
SCHEME="ProcessWatch"
APP_NAME="ProcessWatch"
CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA_DIR="${DERIVED_DATA_DIR:-$ROOT_DIR/build/DerivedData}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
BUILD_LOG="${BUILD_LOG:-$ROOT_DIR/build/xcodebuild.log}"
CLEAN=0
RUN_APP=0
SIGN_APP=1

usage() {
  cat <<'USAGE'
Usage: ./scripts/build_app.sh [options]

Options:
  --debug       Build Debug configuration
  --release     Build Release configuration (default)
  --clean       Remove previous build output before building
  --run         Launch the built application after a successful build
  --no-sign     Do not apply local ad-hoc signing to the copied .app
  -h, --help    Show this help

The complete xcodebuild output is saved to build/xcodebuild.log.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug) CONFIGURATION="Debug" ;;
    --release) CONFIGURATION="Release" ;;
    --clean) CLEAN=1 ;;
    --run) RUN_APP=1 ;;
    --no-sign) SIGN_APP=0 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Error: ProcessWatch can only be built on macOS." >&2
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "Error: xcodebuild was not found. Install Xcode, then run:" >&2
  echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
  exit 1
fi

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "Error: Xcode project not found: $PROJECT_PATH" >&2
  exit 1
fi

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "Error: source directory not found: $SOURCE_DIR" >&2
  echo "Expected a flat project root containing build.sh, ProcessWatch.xcodeproj, Sources, and scripts." >&2
  exit 1
fi

if [[ "$CLEAN" -eq 1 ]]; then
  echo "==> Removing previous build output"
  rm -rf "$DERIVED_DATA_DIR" "$DIST_DIR/$APP_NAME.app" "$BUILD_LOG"
fi

mkdir -p "$DERIVED_DATA_DIR" "$DIST_DIR" "$(dirname "$BUILD_LOG")"

echo "==> Xcode: $(xcodebuild -version | tr '\n' ' ')"
echo "==> Building $APP_NAME ($CONFIGURATION)"
echo "==> Full log: $BUILD_LOG"

set +e
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "platform=macOS" \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build 2>&1 | tee "$BUILD_LOG"
BUILD_STATUS=${PIPESTATUS[0]}
set -e

if [[ "$BUILD_STATUS" -ne 0 ]]; then
  echo >&2
  echo "Build failed. Relevant diagnostics:" >&2
  grep -E "(^|: )(error:|fatal error:)|BUILD FAILED|Signing for" "$BUILD_LOG" | tail -80 >&2 || true
  echo >&2
  echo "Complete log: $BUILD_LOG" >&2
  exit "$BUILD_STATUS"
fi

BUILT_APP="$DERIVED_DATA_DIR/Build/Products/$CONFIGURATION/$APP_NAME.app"
OUTPUT_APP="$DIST_DIR/$APP_NAME.app"

if [[ ! -d "$BUILT_APP" ]]; then
  echo "Error: build completed but the app was not found at:" >&2
  echo "  $BUILT_APP" >&2
  exit 1
fi

echo "==> Copying application to dist/"
rm -rf "$OUTPUT_APP"
ditto "$BUILT_APP" "$OUTPUT_APP"

if [[ "$SIGN_APP" -eq 1 ]]; then
  SIGN_IDENTITY="${SIGN_IDENTITY:--}"
  echo "==> Applying local ad-hoc signature"
  codesign --force --deep --sign "$SIGN_IDENTITY" "$OUTPUT_APP"
  codesign --verify --deep --strict "$OUTPUT_APP"
fi

printf '\nBuild succeeded:\n  %s\n' "$OUTPUT_APP"

if [[ "$RUN_APP" -eq 1 ]]; then
  echo "==> Launching $APP_NAME"
  open "$OUTPUT_APP"
fi
