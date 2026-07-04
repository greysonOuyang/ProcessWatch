# ProcessWatch v1.5 Review Report

## Review 1 — information architecture and interaction

Result: passed static review.

- Top-level navigation is reduced to Overview, Processes, Alerts, and Settings.
- The duplicated standalone Actions page and obsolete metric card were removed.
- The action inspector is reused from Overview, Processes, and Active Alerts.
- Notification clicks route to Active Alerts.
- Active incidents and persistent history are separate modes.

## Review 2 — visual consistency and layout

Result: passed static review; real macOS visual inspection is still required.

- Menu bar and main window use the same explicit background, surface, border, status, and button tokens.
- All pages use 20 pt horizontal and 18 pt vertical insets.
- The title bar isolates its traffic-light reserve instead of shifting page content.
- Overview uses four readable metric cards instead of five compressed cards.
- Table/detail pages use resizable `HSplitView` panes.
- The main window minimum is 1180×720 and defaults to 1420×860.

## Review 3 — history and privacy

Result: passed.

- Existing `anomaly-history.json` remains compatible and is not migrated or deleted.
- A separate bounded `action-history.json` stores user-initiated operations.
- Each history store retains at most 200 records.
- Search, anomaly-kind filtering, JSON export, and independent clearing are available.
- Per-second metric curves remain bounded in memory and are not persisted.
- Privacy and security documentation now describes action history and export risk.

## Review 4 — process-operation safety

Result: passed static review.

- PID 1, invalid PIDs, and ProcessWatch itself remain protected.
- SIGTERM, SIGKILL, orphan-only, high-CPU-only, and script operations require confirmation.
- No automatic privilege escalation or cache deletion was introduced.
- The cleanup-script result means “launched successfully,” not “cleanup completed.”
- Attempted, succeeded, and failed counts are written to action history.

## Review 5 — source and release structure

Result: passed in the packaging environment.

- Swift source parse: passed.
- `swift-format lint`: passed.
- Swift package manifest parse: passed.
- Shell syntax: passed.
- Info.plist and privacy manifest validation: passed.
- Required file and flat archive layout checks: passed.
- Pure Swift navigation/action-history models type-check: passed.

## Remaining macOS-only gate

This packaging environment cannot link AppKit/SwiftUI or launch a macOS app. Before tagging a release, run on a Mac:

```bash
./doctor.sh
./scripts/review_product.sh
./scripts/test_logic.sh
./build.sh --clean --run
```

Then visually verify:

1. traffic-light spacing at 1180×720 and 1420×860;
2. popover background reaches every edge;
3. split-view resizing does not clip the process table or action panel;
4. notification clicks open Alerts;
5. JSON export and clear dialogs work;
6. graceful/force termination only affects confirmed PIDs.
