#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

required=(
  Package.swift VERSION LICENSE README.md README.zh-CN.md
  CONTRIBUTING.md CODE_OF_CONDUCT.md SECURITY.md PRIVACY.md SUPPORT.md
  build.sh run.sh doctor.sh clean.sh
  Support/Info.plist Support/PrivacyInfo.xcprivacy
  Assets/AppIcon.icns Assets/AppIcon.png Assets/AppIcon.svg
  docs/UI_AND_ACTIONS.md docs/IMPLEMENTATION_PLAN_V1.5.md docs/assets/dashboard-concept-v1.4.png
  Tests/LogicTests.swift scripts/test_logic.sh scripts/release_notes.sh scripts/review_product.sh
  Sources/ProcessWatch/ProcessWatchApp.swift
  Sources/ProcessWatch/Models/MetricHistory.swift
  Sources/ProcessWatch/Models/AppSection.swift
  Sources/ProcessWatch/Models/ActionRecord.swift
  Sources/ProcessWatch/Services/ProcessActionService.swift
  Sources/ProcessWatch/Services/ActionHistoryStore.swift
  Sources/ProcessWatch/Views/DesignSystem.swift
  Sources/ProcessWatch/Views/ProcessGroupTableView.swift
  Sources/ProcessWatch/Views/AnomalyActionPanel.swift
  Sources/ProcessWatch/Views/AlertsView.swift
  Sources/ProcessWatch/Views/HistoryView.swift
  Sources/ProcessWatch/Views/ActionRecordRow.swift
  Sources/ProcessWatch/Monitoring/ProcessSampler.swift
  Sources/ProcessWatchC/ProcessBridge.c
  Sources/ProcessWatchC/include/ProcessBridge.h
  .github/workflows/ci.yml
  .github/ISSUE_TEMPLATE/bug_report.yml
)
for path in "${required[@]}"; do
  [[ -e "$path" ]] || { echo "Missing: $path" >&2; exit 1; }
done

bash -n build.sh run.sh clean.sh doctor.sh scripts/*.sh

swift_find_output=""
if command -v xcrun >/dev/null 2>&1; then
  swift_find_output="$(xcrun --find swift 2>&1)" || true
  if [[ -n "$swift_find_output" ]] && [[ "$swift_find_output" != /* ]]; then
    echo "Swift toolchain unavailable: $swift_find_output" >&2
    exit 1
  fi
fi

if command -v swift >/dev/null 2>&1; then
  swift package dump-package >/dev/null
fi


if command -v swiftc >/dev/null 2>&1; then
  while IFS= read -r swift_file; do
    swiftc -frontend -parse "$swift_file" >/dev/null
  done < <(find Sources Tests -type f -name '*.swift' | sort)
  echo 'Swift source syntax is valid.'
fi

if command -v plutil >/dev/null 2>&1; then
  plutil -lint Support/Info.plist Support/PrivacyInfo.xcprivacy >/dev/null
  echo 'Plist files are valid.'
elif command -v python3 >/dev/null 2>&1; then
  python3 - <<'PY'
import plistlib
from pathlib import Path
for path in [Path('Support/Info.plist'), Path('Support/PrivacyInfo.xcprivacy')]:
    with path.open('rb') as fh:
        plistlib.load(fh)
print('Plist files are valid.')
PY
else
  echo 'Warning: plist validation skipped (plutil/python3 unavailable).' >&2
fi

version="$(tr -d '[:space:]' < VERSION)"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]] || {
  echo "Invalid VERSION: $version" >&2
  exit 1
}

grep -q '__VERSION__' Support/Info.plist || { echo 'Info.plist version placeholder missing' >&2; exit 1; }
grep -q 'struct rusage_info_v4' Sources/ProcessWatchC/ProcessBridge.c || {
  echo 'C bridge must use struct rusage_info_v4 for SDK compatibility' >&2
  exit 1
}

if command -v git >/dev/null 2>&1; then
  if git grep -nE '(BEGIN (RSA|OPENSSH|EC) PRIVATE KEY|APPLE_APP_SPECIFIC_PASSWORD=|MACOS_CERTIFICATE=)' -- . ':!scripts/source_check.sh' >/tmp/processwatch-secret-scan.txt 2>/dev/null; then
    echo "Potential secret material found:" >&2
    cat /tmp/processwatch-secret-scan.txt >&2
    exit 1
  fi
fi

echo "Source layout, metadata, scripts, and release assets are valid."
