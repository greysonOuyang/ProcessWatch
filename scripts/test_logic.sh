#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build/logic-tests"
BINARY="$BUILD_DIR/ProcessWatchLogicTests"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Error: logic tests require the macOS Swift toolchain." >&2
  exit 1
fi
mkdir -p "$BUILD_DIR"

xcrun swiftc \
  -swift-version 5 \
  -parse-as-library \
  "$ROOT_DIR/Sources/ProcessWatch/Models/Formatting.swift" \
  "$ROOT_DIR/Sources/ProcessWatch/Models/AnomalyEvent.swift" \
  "$ROOT_DIR/Sources/ProcessWatch/Models/ActionRecord.swift" \
  "$ROOT_DIR/Sources/ProcessWatch/Models/ProcessSnapshot.swift" \
  "$ROOT_DIR/Sources/ProcessWatch/Services/SettingsStore.swift" \
  "$ROOT_DIR/Sources/ProcessWatch/Monitoring/AnomalyDetector.swift" \
  "$ROOT_DIR/Tests/LogicTests.swift" \
  -o "$BINARY"

"$BINARY"
