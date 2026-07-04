#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAILED=0
ok() { printf '✓ %s\n' "$1"; }
fail() { printf '✗ %s\n' "$1" >&2; FAILED=1; }

[[ "$(uname -s)" == "Darwin" ]] && ok "macOS detected" || fail "This app requires macOS"
for path in \
  Package.swift VERSION Support/Info.plist Support/PrivacyInfo.xcprivacy \
  Assets/AppIcon.icns Sources/ProcessWatch/ProcessWatchApp.swift \
  Sources/ProcessWatchC/ProcessBridge.c; do
  [[ -e "$ROOT_DIR/$path" ]] && ok "$path found" || fail "$path missing"
done

if command -v xcrun >/dev/null 2>&1; then
  ok "xcrun found"
  TOOLCHAIN_FIND_OUTPUT="$(xcrun --find swift 2>&1)" || true
  if [[ -n "${TOOLCHAIN_FIND_OUTPUT:-}" ]] && [[ "$TOOLCHAIN_FIND_OUTPUT" != /* ]]; then
    fail "Swift toolchain unavailable: $TOOLCHAIN_FIND_OUTPUT"
  elif [[ -n "${TOOLCHAIN_FIND_OUTPUT:-}" ]]; then
    ok "Swift toolchain: $(xcrun swift --version | head -1)"
  else
    fail "Swift toolchain not selected"
  fi
else
  fail "xcrun missing; install Xcode Command Line Tools"
fi

if command -v plutil >/dev/null 2>&1; then
  plutil -lint "$ROOT_DIR/Support/Info.plist" >/dev/null && ok "Info.plist is valid" || fail "Info.plist is invalid"
  plutil -lint "$ROOT_DIR/Support/PrivacyInfo.xcprivacy" >/dev/null && ok "PrivacyInfo.xcprivacy is valid" || fail "PrivacyInfo.xcprivacy is invalid"
fi

if command -v codesign >/dev/null 2>&1; then
  ok "codesign found"
else
  fail "codesign missing"
fi
if command -v hdiutil >/dev/null 2>&1; then
  ok "hdiutil found"
else
  fail "hdiutil missing"
fi

if [[ "$FAILED" -eq 0 ]]; then
  "$ROOT_DIR/scripts/check_c_bridge.sh" >/dev/null \
    && ok "C monitoring bridge is compatible with the selected macOS SDK" \
    || fail "C monitoring bridge failed the macOS SDK syntax check"
fi

if [[ "$FAILED" -ne 0 ]]; then
  echo >&2
  echo "Environment check failed." >&2
  exit 1
fi

echo
echo "Environment check passed."
echo "Local run:  ./build.sh --clean --run"
echo "Release:    see docs/RELEASING.md"
