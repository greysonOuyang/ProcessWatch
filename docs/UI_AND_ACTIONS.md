# UI and process actions

## Interaction model

ProcessWatch uses four top-level destinations:

- **Overview** — current system health, priority process groups, and the selected-group action panel.
- **Processes** — the complete grouped process browser with expandable PID details.
- **Alerts** — active incidents plus anomaly and user-action history.
- **Settings** — thresholds, suppression rules, privacy, login behavior, and app lifecycle.

The former standalone Actions page was removed in v1.5 because it duplicated the Alerts workflow. The same action panel remains available from Overview, Processes, and Active Alerts.

## Visual system

The menu bar popover and main window share the same:

- charcoal-to-warm-black background gradient;
- raised and standard card surfaces;
- 14 pt card radius;
- amber brand color;
- teal healthy, amber warning, coral critical, and blue informational states;
- button hierarchy and status pills;
- 20 pt page margin and 12 pt card gap.

The custom title bar reserves space for the macOS traffic-light controls without shifting page content. Table/detail screens use `HSplitView`, allowing the user to resize the inspector.

## Process grouping

Processes are grouped by full executable path where available. Each group shows:

- instance count;
- aggregate CPU, memory, read, and write rates;
- orphan count;
- longest runtime;
- repo-harness/Codex affiliation.

Expanded rows show PID, PPID, full command, parent process, working directory, CPU, memory, and orphan state.

## Active anomaly operations

The action panel exposes two levels of actions.

### Resource remediation

- Terminate orphan instances with `SIGTERM`.
- Terminate only instances above the configured CPU threshold.
- Gracefully terminate all controllable instances with `SIGTERM`.
- Force quit all controllable instances with `SIGKILL`.

ProcessWatch automatically excludes PID 1, invalid PIDs, and its own process. It does not elevate privileges. Failures are reported per PID when available.

### Investigation and suppression

- Ignore alerts for one hour while continuing to sample.
- Add or remove a path-scoped whitelist entry.
- Reveal the executable in Finder.
- Copy the representative full command.
- Open Activity Monitor.
- Launch a user-selected script after explicit confirmation.

## Action history

Remediation and supporting actions initiated from the action panel are stored locally in `action-history.json`, with:

- process name and executable path;
- action type;
- outcome;
- attempted, succeeded, and failed counts;
- timestamp and result summary.

The Alerts history interface supports search, anomaly-kind filtering, independent clearing, and JSON export.

## Memory cleanup policy

ProcessWatch intentionally does not offer a generic “clean memory” button. macOS manages free, compressed, cached, and reclaimable memory dynamically. When an abnormal process exits, the operating system reclaims its memory, CPU scheduling resources, mappings, and file handles.

A cleanup script is an advanced user action, not an automatic recommendation. ProcessWatch does not inspect, rewrite, elevate, or silently execute scripts.

## History retention

Persistent:

- up to 200 anomaly events;
- up to 200 user-action records.

Not persistent:

- per-second CPU charts;
- memory, disk, or process-count metric streams;
- general process command history.

Metric charts are held in a bounded in-memory buffer only.
