# ProcessWatch v1.5 UI and Interaction Plan

## Goals

1. Unify the menu bar popover and main window under one visual system.
2. Correct inconsistent margins and make the main window responsive down to 1180×720.
3. Remove duplicated navigation between Alerts and Actions.
4. Preserve useful anomaly history while separating current incidents from historical records.
5. Record user-initiated remediation actions for troubleshooting and accountability.
6. Keep resource cleanup truthful and safe: no fake memory purge feature.

## Information architecture

Top-level destinations:

- Overview: current system state, priority process groups, selected-group actions.
- Processes: complete grouped process browser and identity details.
- Alerts: Active incidents and History (anomaly events + user actions).
- Settings: thresholds, suppression, privacy, and app lifecycle.

The former standalone Actions destination is merged into Alerts. The action panel remains available from Overview, Processes, and Active Alerts.

## History policy

Keep:

- Persistent anomaly events, up to 200 records.
- Persistent user action records, up to 200 records.
- Search, kind filtering, JSON export, and explicit clearing.

Do not persist:

- Per-second CPU, memory, disk, or process-count charts.
- Full process command histories.

Metric charts stay in memory as a bounded short window. This keeps the application lightweight and avoids retaining sensitive command-line data unnecessarily.

## Layout system

- Page horizontal inset: 20 pt.
- Page vertical inset: 18 pt.
- Standard gap: 12 pt.
- Card corner radius: 14 pt.
- Main window: 1420×860 default, 1180×720 minimum.
- Metric cards use four responsive columns instead of forcing five narrow cards.
- Main table/detail layouts use HSplitView so the user can resize the action panel.
- The title bar reserves a dedicated traffic-light spacer rather than applying a large leading padding to the entire toolbar.

## Visual system

- Neutral charcoal base instead of mixing system gray and brown surfaces.
- Warm amber is the brand/accent color.
- Teal is healthy, amber is warning, coral-red is critical, blue is informational.
- Menu bar and main window use the same background gradient, card fill, border, pills, button hierarchy, and typography.

## Remediation model

Primary actions:

- Graceful terminate (SIGTERM).
- Terminate only orphan instances.
- Terminate only high-CPU instances.
- Force quit (SIGKILL) as an explicitly destructive fallback.

Supporting actions:

- Ignore for one hour.
- Add/remove whitelist.
- Reveal executable or working directory.
- Copy representative command.
- Open Activity Monitor.
- Run a user-selected cleanup script after confirmation.

All meaningful actions are recorded locally in action history. ProcessWatch never automatically deletes caches, elevates privileges, or claims to provide a universal memory cleaner.

## Review gates

1. Source syntax and package manifest parsing.
2. Shell script and plist validation.
3. Navigation and state ownership review.
4. Suppression/history migration review.
5. Dangerous-action confirmation and protected-PID review.
6. ZIP root-layout and executable-script verification.
7. Final macOS build remains required on a real Mac because AppKit cannot be linked in the Linux packaging environment.
