#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

./scripts/source_check.sh

[[ ! -e Sources/ProcessWatch/Views/ActionCenterView.swift ]] || {
  echo "Obsolete standalone ActionCenterView still exists" >&2
  exit 1
}
[[ ! -e Sources/ProcessWatch/Views/MetricCard.swift ]] || {
  echo "Obsolete MetricCard still exists" >&2
  exit 1
}

for route in overview processes alerts settings; do
  grep -q "case $route" Sources/ProcessWatch/Models/AppSection.swift || {
    echo "Missing top-level route: $route" >&2
    exit 1
  }
done
if grep -q 'case actions' Sources/ProcessWatch/Models/AppSection.swift; then
  echo "Duplicated top-level Actions route must not return" >&2
  exit 1
fi

grep -q 'pageHorizontal: CGFloat = 24' Sources/ProcessWatch/Views/DesignSystem.swift
grep -q 'popoverBackground' Sources/ProcessWatch/Views/MenuBarView.swift
grep -q 'windowBackground' Sources/ProcessWatch/Views/MainView.swift
grep -q 'action-history.json' Sources/ProcessWatch/Services/ActionHistoryStore.swift
grep -q 'maxRecords = 200' Sources/ProcessWatch/Services/ActionHistoryStore.swift
grep -q 'maxEvents = 200' Sources/ProcessWatch/Services/HistoryStore.swift
grep -q 'process.pid > 1 && process.pid != getpid()' Sources/ProcessWatch/Services/ProcessActionService.swift
grep -q 'alertState = .confirm' Sources/ProcessWatch/Views/AnomalyActionPanel.swift
grep -q 'onOpenAlerts' Sources/ProcessWatch/Services/NotificationService.swift
grep -q 'JSON' Sources/ProcessWatch/Views/HistoryView.swift

if command -v swift-format >/dev/null 2>&1; then
  swift-format lint --recursive Sources Tests
fi

echo "Product review checks passed."

grep -q 'struct DashboardSplit' Sources/ProcessWatch/Views/DesignSystem.swift
if grep -R 'HSplitView' Sources/ProcessWatch/Views >/dev/null; then
  echo 'HSplitView must not be used for dashboard panes; it caused panel overlap and missing spacing' >&2
  exit 1
fi
grep -q 'ProcessWatch.MainWindow.v1.5.1' Sources/ProcessWatch/Views/WindowManager.swift
