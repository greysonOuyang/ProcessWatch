#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")}"

awk -v version="$VERSION" '
  $0 ~ "^## " version "([[:space:]-]|$)" { found=1; next }
  found && /^## / { exit }
  found { print }
' "$ROOT_DIR/CHANGELOG.md"
