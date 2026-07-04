#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_FILE="$ROOT_DIR/Sources/ProcessWatchC/ProcessBridge.c"
INCLUDE_DIR="$ROOT_DIR/Sources/ProcessWatchC/include"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Error: the C bridge check requires macOS." >&2
  exit 1
fi

if ! command -v xcrun >/dev/null 2>&1; then
  echo "Error: xcrun was not found." >&2
  exit 1
fi

SDK_PATH="$(xcrun --sdk macosx --show-sdk-path)"
CLANG="$(xcrun --sdk macosx --find clang)"

"$CLANG" \
  -isysroot "$SDK_PATH" \
  -mmacosx-version-min=13.0 \
  -std=c11 \
  -Wall \
  -Wextra \
  -Werror=implicit-function-declaration \
  -I "$INCLUDE_DIR" \
  -fsyntax-only \
  "$SOURCE_FILE"

echo "✓ C monitoring bridge compiles with the selected macOS SDK"
