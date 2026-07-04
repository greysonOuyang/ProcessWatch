<p align="center">
  <img src="docs/assets/logo-256.png" width="128" height="128" alt="ProcessWatch icon">
</p>

<h1 align="center">ProcessWatch</h1>

<p align="center">
  A local-first macOS menu bar utility for detecting persistent process anomalies.
</p>

<p align="center">
  <img alt="Platform" src="https://img.shields.io/badge/macOS-13%2B-111827">
  <img alt="Swift" src="https://img.shields.io/badge/Swift-5.9%2B-F05138">
  <img alt="License" src="https://img.shields.io/badge/license-MIT-44DED2">
  <img alt="Status" src="https://img.shields.io/badge/status-beta-FFAE3A">
</p>

[简体中文](README.zh-CN.md)

ProcessWatch watches CPU usage, memory growth, disk writes, process storms, orphan processes, and repo-harness/Codex process ancestry. It aggregates identical executables before showing individual PIDs, so dozens of `bun` instances become one diagnosable group instead of a flat list.

<p align="center">
  <img src="docs/assets/dashboard-concept-v1.4.png" width="900" alt="ProcessWatch dashboard design concept">
</p>

> The image above is a design concept. The implementation follows the same information architecture using native SwiftUI/AppKit components.

> **Project status:** public beta. The app is useful for local diagnostics, but its native process sampling and release pipeline should be validated on multiple macOS and hardware versions before declaring a stable 1.0 release.

## Highlights

- Unified native dark interface with Overview, Processes, Alerts, and Settings; the menu bar popover and main window share one visual system
- Menu bar CPU status and anomaly indicator
- Real trend cards for system CPU, memory pressure, aggregate process disk writes, process/orphan count, and thermal state
- Grouping by executable path with aggregate CPU, memory, I/O, orphan count, and longest runtime
- PID, PPID, full command line, working directory, launch time, parent process, and ancestry affiliation
- Persistent high CPU, memory growth, disk-write, process-storm, and repo-harness orphan-leak alerts
- Incident center with separate Active and History modes, plus graceful terminate, force quit, orphan/high-CPU targeting, snooze, whitelist, Finder, command copy, and Activity Monitor
- User-selected cleanup scripts with explicit confirmation; no misleading generic “clean memory” operation
- Persistent anomaly and user-action history with search, filters, JSON export, notifications, and configurable thresholds
- No analytics, telemetry, account, cloud service, or network upload
- Native SwiftUI + AppKit + libproc/Mach implementation with no runtime third-party dependencies

## Quick start from source

Requirements:

- macOS 13 or later
- Xcode 15 or later, or compatible Xcode Command Line Tools

```bash
./doctor.sh
./build.sh --clean --run
```

The app bundle is created at:

```text
dist/ProcessWatch.app
```

Other commands:

```bash
make check             # source, metadata, and script checks
make review            # UI/history/safety product checks
make build             # native Release build
make universal         # arm64 + x86_64 app
make dmg               # versioned DMG
make install           # install to ~/Applications
make install-system    # install to /Applications (uses sudo)
```

Open `Package.swift` in Xcode for source navigation and debugging.

## Release distribution

Local builds use an ad-hoc signature and are intended only for development. A public binary release should be:

1. built as a universal binary;
2. signed with a Developer ID Application certificate and Hardened Runtime;
3. notarized by Apple;
4. stapled and verified;
5. published with SHA-256 checksums.

The included release script performs that workflow after signing credentials are configured:

```bash
export DEVELOPER_ID_APPLICATION='Developer ID Application: Your Name (TEAMID)'
export NOTARY_PROFILE='ProcessWatchNotary'
./scripts/release.sh
```

See [docs/RELEASING.md](docs/RELEASING.md).

## Privacy and security

ProcessWatch reads local process and system resource metadata. It does not transmit monitoring data. Anomaly history, user-action history, and preferences remain in the current macOS user account. Per-second metric charts stay in a bounded in-memory window and are not retained long term. Some process fields cannot be read without additional privileges and are shown as unavailable rather than requesting root access.

Read [PRIVACY.md](PRIVACY.md) and [SECURITY.md](SECURITY.md) before distributing the app.

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [v1.5 interaction and feature plan](docs/IMPLEMENTATION_PLAN_V1.5.md)
- [UI and process actions](docs/UI_AND_ACTIONS.md)
- [Building](docs/BUILDING.md)
- [Releasing](docs/RELEASING.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Roadmap](docs/ROADMAP.md)
- [GitHub repository setup](docs/GITHUB_SETUP.md)
- [Open-source release audit](docs/OPEN_SOURCE_RELEASE_AUDIT.md)
- [Contributing](CONTRIBUTING.md)
- [Support](SUPPORT.md)

## Branding

The source logo, PNG assets, and `.icns` app icon are under `Assets/` and `docs/assets/`. They are distributed under the same MIT license as the project. The icon represents process activity, continuous observation, and an anomaly alert.

## License and disclaimer

ProcessWatch is available under the [MIT License](LICENSE). It is not affiliated with Apple, OpenAI, Codex, Bun, or repo-harness. Process classification is heuristic and should be confirmed before terminating a process.
