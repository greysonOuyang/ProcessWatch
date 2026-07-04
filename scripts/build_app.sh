#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="ProcessWatch"
CONFIGURATION="release"
CLEAN=0
RUN_APP=0
SIGN_MODE="adhoc"
SIGN_IDENTITY=""
UNIVERSAL=0
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build}"
SCRATCH_DIR="${SCRATCH_DIR:-$BUILD_DIR/swiftpm}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
LOG_FILE="${LOG_FILE:-$BUILD_DIR/swift-build.log}"
APP_PATH="$DIST_DIR/$APP_NAME.app"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"
BUILD_NUMBER="${BUILD_NUMBER:-${GITHUB_RUN_NUMBER:-$(printf '%s' "$VERSION" | tr -cd '0-9')}}"

usage() {
  cat <<'USAGE'
Usage: ./build.sh [options]

Options:
  --debug                     Build Debug configuration
  --release                   Build Release configuration (default)
  --clean                     Remove build/ and dist/ before building
  --run                       Launch ProcessWatch after a successful build
  --universal                 Build a universal arm64 + x86_64 executable
  --no-sign                   Do not sign the app bundle
  --sign-identity "NAME"      Sign with a Developer ID Application identity
  -h, --help                  Show this help

Environment:
  BUILD_NUMBER                Override CFBundleVersion
  BUILD_DIR, SCRATCH_DIR      Override build directories
  DIST_DIR, LOG_FILE          Override output locations

Output:
  dist/ProcessWatch.app
  build/swift-build.log
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --debug) CONFIGURATION="debug" ;;
    --release) CONFIGURATION="release" ;;
    --clean) CLEAN=1 ;;
    --run) RUN_APP=1 ;;
    --universal) UNIVERSAL=1 ;;
    --no-sign) SIGN_MODE="none" ;;
    --sign-identity)
      shift
      [[ $# -gt 0 ]] || { echo "Missing value for --sign-identity" >&2; exit 2; }
      SIGN_MODE="developer-id"
      SIGN_IDENTITY="$1"
      ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Error: ProcessWatch can only be built on macOS." >&2
  exit 1
fi

required=(
  Package.swift VERSION Support/Info.plist Support/PrivacyInfo.xcprivacy
  Assets/AppIcon.icns Sources/ProcessWatch/ProcessWatchApp.swift
)
for path in "${required[@]}"; do
  [[ -e "$ROOT_DIR/$path" ]] || { echo "Error: missing $path" >&2; exit 1; }
done

toolchain_error() {
  local find_output
  if ! command -v xcrun >/dev/null 2>&1; then
    echo "xcrun is not installed." >&2
    return
  fi

  find_output="$(xcrun --find swift 2>&1)" || true
  if [[ -n "$find_output" ]]; then
    echo "$find_output" >&2
  fi
}

if ! command -v xcrun >/dev/null 2>&1 || ! xcrun --find swift >/dev/null 2>&1; then
  echo "Error: Swift/Xcode toolchain was not found." >&2
  echo "Install Xcode, then select it with:" >&2
  echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
  echo "Additional diagnostics:" >&2
  toolchain_error
  exit 1
fi

if [[ "$CLEAN" -eq 1 ]]; then
  echo "==> Cleaning previous output"
  rm -rf "$BUILD_DIR" "$DIST_DIR" "$ROOT_DIR/.build"
fi
mkdir -p "$BUILD_DIR" "$DIST_DIR"
: > "$LOG_FILE"

"$ROOT_DIR/scripts/check_c_bridge.sh"

CONFIG_LABEL="Release"
[[ "$CONFIGURATION" == "debug" ]] && CONFIG_LABEL="Debug"
echo "==> Project: $ROOT_DIR"
echo "==> Version: $VERSION ($BUILD_NUMBER)"
echo "==> Toolchain: $(xcrun swift --version | head -1)"
echo "==> Building $APP_NAME ($CONFIG_LABEL)"
echo "==> Full log: $LOG_FILE"

build_for_arch() {
  local arch="$1"
  local output_variable="$2"
  local arch_scratch="$SCRATCH_DIR/$arch"
  local triple="${arch}-apple-macosx13.0"

  echo "==> Building architecture: $arch" | tee -a "$LOG_FILE"
  set +e
  (
    cd "$ROOT_DIR"
    xcrun swift build \
      --configuration "$CONFIGURATION" \
      --scratch-path "$arch_scratch" \
      --triple "$triple"
  ) 2>&1 | tee -a "$LOG_FILE"
  local status=${PIPESTATUS[0]}
  set -e
  [[ "$status" -eq 0 ]] || return "$status"

  local bin_dir
  bin_dir="$(
    cd "$ROOT_DIR"
    xcrun swift build \
      --configuration "$CONFIGURATION" \
      --scratch-path "$arch_scratch" \
      --triple "$triple" \
      --show-bin-path
  )"
  printf -v "$output_variable" '%s' "$bin_dir"
}

build_native() {
  local output_variable="$1"
  echo "==> Building native architecture" | tee -a "$LOG_FILE"
  set +e
  (
    cd "$ROOT_DIR"
    xcrun swift build \
      --configuration "$CONFIGURATION" \
      --scratch-path "$SCRATCH_DIR/native"
  ) 2>&1 | tee -a "$LOG_FILE"
  local status=${PIPESTATUS[0]}
  set -e
  [[ "$status" -eq 0 ]] || return "$status"

  local bin_dir
  bin_dir="$(
    cd "$ROOT_DIR"
    xcrun swift build \
      --configuration "$CONFIGURATION" \
      --scratch-path "$SCRATCH_DIR/native" \
      --show-bin-path
  )"
  printf -v "$output_variable" '%s' "$bin_dir"
}

STATUS=0
if [[ "$UNIVERSAL" -eq 1 ]]; then
  ARM_BIN_DIR=""
  X86_BIN_DIR=""
  build_for_arch arm64 ARM_BIN_DIR || STATUS=$?
  if [[ "$STATUS" -eq 0 ]]; then
    build_for_arch x86_64 X86_BIN_DIR || STATUS=$?
  fi
else
  NATIVE_BIN_DIR=""
  build_native NATIVE_BIN_DIR || STATUS=$?
fi

if [[ "$STATUS" -ne 0 ]]; then
  echo >&2
  echo "Build failed. Relevant diagnostics:" >&2
  grep -n -E "error:|fatal error:|BUILD FAILED" "$LOG_FILE" | tail -120 >&2 || true
  echo >&2
  echo "Complete log: $LOG_FILE" >&2
  exit "$STATUS"
fi

rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"

if [[ "$UNIVERSAL" -eq 1 ]]; then
  ARM_BINARY="$ARM_BIN_DIR/$APP_NAME"
  X86_BINARY="$X86_BIN_DIR/$APP_NAME"
  [[ -x "$ARM_BINARY" && -x "$X86_BINARY" ]] || {
    echo "Error: one or more architecture binaries are missing." >&2
    exit 1
  }
  xcrun lipo -create "$ARM_BINARY" "$X86_BINARY" -output "$APP_PATH/Contents/MacOS/$APP_NAME"
else
  BINARY_PATH="$NATIVE_BIN_DIR/$APP_NAME"
  [[ -x "$BINARY_PATH" ]] || { echo "Error: executable not found: $BINARY_PATH" >&2; exit 1; }
  install -m 755 "$BINARY_PATH" "$APP_PATH/Contents/MacOS/$APP_NAME"
fi

cp "$ROOT_DIR/Support/Info.plist" "$APP_PATH/Contents/Info.plist"
cp "$ROOT_DIR/Support/PrivacyInfo.xcprivacy" "$APP_PATH/Contents/Resources/PrivacyInfo.xcprivacy"
cp "$ROOT_DIR/Assets/AppIcon.icns" "$APP_PATH/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP_PATH/Contents/PkgInfo"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP_PATH/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP_PATH/Contents/Info.plist"

case "$SIGN_MODE" in
  none)
    echo "==> Skipping code signing"
    ;;
  adhoc)
    echo "==> Applying local ad-hoc signature"
    /usr/bin/codesign --force --deep --sign - "$APP_PATH"
    /usr/bin/codesign --verify --deep --strict "$APP_PATH"
    ;;
  developer-id)
    echo "==> Signing with Developer ID: $SIGN_IDENTITY"
    /usr/bin/codesign \
      --force \
      --options runtime \
      --timestamp \
      --sign "$SIGN_IDENTITY" \
      "$APP_PATH"
    /usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_PATH"
    ;;
esac

printf '\nBuild succeeded:\n  %s\n' "$APP_PATH"
if [[ "$UNIVERSAL" -eq 1 ]]; then
  echo "Architectures: $(xcrun lipo -archs "$APP_PATH/Contents/MacOS/$APP_NAME")"
fi

if [[ "$RUN_APP" -eq 1 ]]; then
  echo "==> Launching $APP_NAME"
  /usr/bin/open -n "$APP_PATH"
fi
