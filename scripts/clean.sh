#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
rm -rf "$ROOT_DIR/build" "$ROOT_DIR/dist" "$ROOT_DIR/.build"
echo "Removed build/, dist/, and .build/."
