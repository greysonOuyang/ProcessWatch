# 1.1.4

- 修正源码包目录设计：内部源码目录由 `ProcessWatch/` 改为 `Sources/`。
- ZIP 根目录直接包含 `build.sh`、`ProcessWatch.xcodeproj`、`Sources/`、`scripts/`。
- 增加 `START_HERE.command`，可在 Finder 中双击构建并运行。
- 更新 Xcode 工程、Bridging Header、Info.plist、资源和 XcodeGen 路径。

# Changelog

## 1.1.3

- Fixed `PWProcessSample.command_line` compile failures caused by Xcode/Clang importer differences.
- Added stable C accessor functions for process identity, CPU ticks, and memory metrics.
- Removed all direct Swift access to snake_case C struct fields and fixed-size C character arrays.
- This prevents the same compatibility issue from recurring for working directory, CPU, and memory fields.

## 1.1.1

- Fixed the C bridge declaration of `rusage_info_v4` for macOS SDK compatibility.
- Replaced SDK-sensitive hierarchical style opacity expressions with explicit colors.
- Disabled Xcode automatic signing during command-line builds; the output is ad-hoc signed afterward.
- Added `build/xcodebuild.log` and concise failure diagnostics.
- Made “退出 ProcessWatch” visible in the menu-bar panel and Settings.
- Added Command-Q application termination.

## 1.1

- Added executable-based process grouping and PID details.
- Added process storm and repo-harness orphan leak detection.
- Added memory pressure, swap, compressed memory and reclaimable cache metrics.
