# ProcessWatch 1.4 implementation plan

## Goal

Turn ProcessWatch from a functional monitoring utility into a product-quality
native macOS dashboard, while adding safe and diagnosable actions for persistent
CPU, memory-growth, disk-write, and process-storm anomalies.

## Phase 1 — Information architecture

- Replace the standard tab view with a custom native macOS navigation bar.
- Add Overview, Processes, Alerts, Actions, and Settings sections.
- Use a dark dashboard surface with clear severity colors and restrained charts.
- Keep the menu-bar popover compact; move destructive operations to the main window.

Acceptance criteria:

- The main window remains usable at 1260 × 760.
- Current system state and the selected process group are visible without opening
  another sheet.
- No metric is fabricated: cards only use values sampled by ProcessWatch.

## Phase 2 — Process diagnosis

- Show process groups before individual instances.
- Expand a group into PID, PPID, command, working directory, CPU, memory, and state.
- Keep executable-path grouping so unrelated `bun` instances can be diagnosed
  separately.
- Prioritize active anomalies above ordinary high-usage groups.

Acceptance criteria:

- A process storm can be identified at group level.
- A user can inspect the command and working directory before taking action.
- Whitelist and one-hour snooze rules are scoped to the executable path where
  possible, not globally to every process with the same short name.

## Phase 3 — Safe operations

- Add graceful group termination with `SIGTERM`.
- Add force quit with `SIGKILL` as a secondary action.
- Add orphan-only and high-CPU-only termination.
- Exclude PID 1 and ProcessWatch itself.
- Report per-action success and failure counts.
- Add Finder reveal, command copy, and Activity Monitor launch.
- Add a user-selected cleanup-script entry point with confirmation.

Acceptance criteria:

- Every destructive action requires confirmation.
- No operation requests root or silently retries with privilege escalation.
- ProcessWatch never performs generic memory purging or automatic cache deletion.

## Phase 4 — State and alert controls

- Maintain rolling metric histories for dashboard sparklines.
- Add one-hour alert snoozing while sampling continues.
- Keep a permanent executable-path whitelist.
- Surface active anomaly count in the main navigation and menu-bar popover.

Acceptance criteria:

- Snoozed processes disappear from new anomaly evaluation until the deadline.
- Whitelisted processes remain visible in monitoring views.
- Existing name-based ignore entries continue to work for backward compatibility.

## Phase 5 — Verification and release

- Parse every Swift source file in `scripts/source_check.sh`.
- Keep the macOS C bridge preflight check.
- Run logic tests for grouping, process storms, snoozing, and whitelisting.
- Build on a macOS CI runner and upload the build log on failure.
- Ship a flat source archive with root-level build scripts.

Known limitation:

- The current execution environment is Linux, so the final AppKit/SwiftUI link and
  launch test must run on macOS or GitHub Actions.
