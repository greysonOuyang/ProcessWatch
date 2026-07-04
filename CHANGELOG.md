# Changelog

## 1.5.0 - Unified interface and incident history

- Unified the menu bar popover and main window under one dark charcoal/amber design system.
- Reworked window spacing, page margins, title-bar traffic-light reservation, and split-pane sizing.
- Reduced top-level navigation to Overview, Processes, Alerts, and Settings.
- Merged the former standalone Actions page into the Active Alerts workflow.
- Added a combined Alerts center with Active incidents and persistent History modes.
- Added local user-action history for terminate, force quit, snooze, whitelist, reveal, command copy, Activity Monitor, and cleanup-script operations.
- Added history search, anomaly-kind filtering, JSON export, and independent clearing.
- Notification clicks now open the Active Alerts view.
- Rebuilt Settings with the same cards, colors, spacing, and button hierarchy as the rest of the app.
- Improved process-table selection, expansion, contextual actions, and command/parent/working-directory details.
- Kept metric curves as a bounded in-memory window while retaining only diagnostic anomaly/action events on disk.
- Clarified that ProcessWatch does not provide a fake universal memory cleaner.

## 1.4.0 - Dashboard and action center

- Replaced the standard tab UI with a native dark macOS monitoring dashboard.
- Added real-time trend cards for CPU, memory, aggregate disk writes, process
  count, orphan count, and thermal state.
- Added a reusable grouped-process table with expandable PID/PPID, command,
  working directory, CPU, memory, and status rows.
- Added an anomaly action panel and dedicated action center.
- Added graceful group termination, force quit, orphan-only termination, and
  high-CPU-only termination with confirmation and per-PID result reporting.
- Added one-hour alert snoozing and permanent process whitelisting.
- Added Finder reveal, command copy, Activity Monitor launch, and user-selected
  cleanup-script launch.
- Explicitly removed the concept of a generic “clean memory” operation; macOS
  reclaims resources when the responsible process exits.
- Increased the main window size and added transparent full-size title-bar styling.
- Added UI/action architecture documentation and a clearly labeled design concept.

All notable changes are documented here. The project follows semantic versioning while in public beta.

## 1.3.0 - 2026-07-03

### Added

- New ProcessWatch app icon, SVG source, PNG assets, and GitHub social preview.
- MIT open-source community files: contribution guide, code of conduct, security policy, support guide, privacy policy, issue forms, and pull-request template.
- GitHub Actions CI for source validation, native logic tests, and a release build.
- Optional signed release workflow for Developer ID, universal binaries, Apple notarization, stapling, Gatekeeper verification, and GitHub Release upload.
- Versioned DMG packaging and SHA-256 checksums.
- Native grouping and process-storm logic smoke tests.
- About/privacy section, local data folder shortcut, and redacted diagnostics copy action.
- Architecture, building, release, troubleshooting, roadmap, and release-checklist documentation.

### Changed

- Public build metadata now comes from `VERSION` and is injected into the app bundle.
- Public release builds support arm64 + x86_64 universal executables.
- Developer ID signing enables Hardened Runtime and a secure timestamp.
- Installation defaults to `~/Applications`; system installation is explicit.
- The installer no longer removes Gatekeeper quarantine attributes.
- Process termination now blocks PID 1 and the ProcessWatch process itself, with stronger warning text.
- README is now bilingual and clearly labels the project as beta.

### Security and privacy

- Added a privacy manifest declaring no tracking or collected data and documenting app-scoped UserDefaults use.
- Added release credential handling guidance and secret scanning in source checks.
- Documented that ProcessWatch runs without root access and does not upload process metadata.

## 1.2.1

- Fixed macOS SDK compilation of `rusage_info_v4` by using its required `struct` tag.
- Added a native C bridge syntax check to `doctor.sh` and the build script.
- Improved build diagnostics so C bridge failures are shown before the SwiftPM build starts.
- Added a warning when the source is extracted into a directory whose name suggests it belongs to another project.

## 1.2.0

- 改为 Swift Package Manager 工程，删除手写 Xcode 工程与 Bridging Header 依赖。
- C 采样代码作为独立 `ProcessWatchC` 模块导入，Swift 不直接读取 C 定长数组字段。
- ZIP 根目录直接包含 `build.sh`、`Package.swift` 和 `Sources/`，不再出现双层同名源码目录。
- 新增 `doctor.sh`、`source_check.sh`、双击启动脚本和更明确的构建日志。
- 构建脚本自动组装 `.app`、执行本地 ad-hoc 签名并可直接启动。
- 保留同名进程聚合、完整进程身份、进程风暴、repo-harness 泄漏、内存压力和退出入口。
