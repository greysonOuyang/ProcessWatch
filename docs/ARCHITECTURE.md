# Architecture

ProcessWatch is a macOS menu bar app assembled from a Swift Package executable and a small C target.

## Layers

- **UI** — SwiftUI views plus an AppKit window manager and menu bar host.
- **Application model** — coordinates sampling, anomaly evaluation, notifications, history, and settings.
- **Sampling** — `ProcessSampler` and `SystemSampler` convert cumulative kernel counters into interval rates.
- **Native bridge** — `ProcessWatchC` wraps libproc, sysctl, Mach, and process resource APIs behind stable C accessors.
- **Detection** — `AnomalyDetector` maintains per-PID and per-executable-group state machines.
- **Persistence** — `UserDefaults` for preferences and JSON for bounded alert history.

## Sampling model

Process counters such as CPU time and disk bytes are cumulative. ProcessWatch stores the previous sample and calculates non-negative deltas over elapsed monotonic wall time. PID reuse and counter reset are handled by discarding negative deltas and rebuilding identity state when names change.

Processes are grouped by executable path, falling back to a lowercased process name only when the path is unavailable. Group metrics are sums across current instances.

## Concurrency

Sampling actors perform process and system collection away from the main actor. `AppModel` owns UI-facing state on the main actor. The monitoring loop samples process and system data concurrently, evaluates anomalies, then publishes a coherent snapshot.

## Anomaly state

Anomaly rules are persistent state machines rather than instantaneous thresholds:

- CPU and disk rules track continuous time above a threshold.
- Memory growth compares points across a configured observation window.
- Process storm tracks the number of current instances in an executable group.
- repo-harness leakage requires orphan ancestry classification and minimum runtime.
- Alerts use a cooldown and clear when the condition recovers.

## Security boundary

The app intentionally runs as the current user without a privileged helper, daemon, kernel extension, or root authorization. Missing process fields are expected. Automatic force termination is out of scope.

## Packaging

`build.sh` uses SwiftPM, creates a standard `.app` bundle, injects version metadata, copies the privacy manifest and app icon, and applies either an ad-hoc or Developer ID signature. `scripts/release.sh` adds universal build, notarization, stapling, verification, DMG packaging, and checksums.
