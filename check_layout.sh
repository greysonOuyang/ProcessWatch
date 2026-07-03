#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
required=(
  "$ROOT_DIR/build.sh"
  "$ROOT_DIR/ProcessWatch.xcodeproj/project.pbxproj"
  "$ROOT_DIR/Sources/ProcessWatchApp.swift"
  "$ROOT_DIR/Sources/Supporting/ProcessBridge.c"
  "$ROOT_DIR/scripts/build_app.sh"
)
for path in "${required[@]}"; do
  if [[ ! -e "$path" ]]; then
    echo "Missing: $path" >&2
    exit 1
  fi
done
if [[ -d "$ROOT_DIR/ProcessWatch" ]]; then
  echo "Unexpected duplicate source directory: $ROOT_DIR/ProcessWatch" >&2
  exit 1
fi
echo "Layout OK"
echo "Project root: $ROOT_DIR"
echo "Build command: ./build.sh --clean --run"
