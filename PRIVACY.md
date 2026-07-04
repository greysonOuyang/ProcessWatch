# Privacy Policy

Last updated: 2026-07-03

ProcessWatch is a local system utility. It does not provide analytics, advertising, user accounts, cloud synchronization, or remote telemetry.

## Data ProcessWatch reads

To diagnose resource anomalies, the app may read metadata exposed by macOS for local processes, including process names, executable paths, command-line arguments, working directories, parent process IDs, launch times, CPU time, physical memory footprint, and disk I/O counters. macOS may deny access to some processes; ProcessWatch does not attempt to bypass those restrictions.

## Data stored locally

- Alert history is stored in `~/Library/Application Support/ProcessWatch/anomaly-history.json`.
- Thresholds, ignored process names, and other preferences are stored in the app's `UserDefaults` domain.
- Build logs created from source are stored inside the source checkout under `build/`.

## Data transmission

ProcessWatch does not intentionally send process data, commands, paths, history, or preferences over the network. The current source contains no network client and no third-party analytics SDK.

## Notifications and login item

The app may request macOS notification permission. Login-at-launch is optional and managed through Apple's ServiceManagement framework.

## Removing data

Clear alert history from the app, then remove the app. To remove all remaining local data, delete:

```text
~/Library/Application Support/ProcessWatch/
```

Preferences may also be removed with:

```bash
defaults delete com.greyson.processwatch
```

## Future changes

Any future feature that transmits data must be opt-in, documented before release, and reflected in this policy and the privacy manifest.

## User-selected scripts

ProcessWatch does not download, generate, inspect, or upload cleanup scripts. If
the user selects a local script from the action panel, the script is launched
locally with the current user's permissions. The selected script path is not sent
anywhere and is not added to anomaly history.


## Local action history

ProcessWatch records user-initiated remediation results locally, including the process name, executable path, action type, timestamp, and success/failure counts. These records are stored in `action-history.json` under the current user’s Application Support directory. They are never uploaded.

Per-second CPU, memory, disk, and process-count chart samples are held only in a bounded in-memory buffer and are not retained across launches. JSON export occurs only after the user explicitly chooses a destination.
