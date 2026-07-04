# Troubleshooting

## `./build.sh: no such file or directory`

You are not in the project root. The correct directory contains `Package.swift`, `build.sh`, `Sources/`, and `scripts/`.

```bash
pwd
find . -maxdepth 3 -name build.sh -print
```

## Swift or SDK is not selected

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
./doctor.sh
```

## C bridge compilation fails

```bash
./scripts/check_c_bridge.sh
```

The bridge intentionally uses `struct rusage_info_v4` for compatibility with SDKs that do not expose a typedef for that type.

## Build log

```bash
grep -n -A 8 -B 8 "error:" build/swift-build.log
```

## App launches but no window appears

ProcessWatch is a menu bar app. Click its menu bar icon, then choose **打开主界面**. The app does not appear in the Dock by design.

## Closing the window does not quit

This is expected. Use the menu bar **退出 ProcessWatch** button or Command-Q.

## Login item cannot be enabled

Install or run a correctly assembled `.app` bundle rather than the raw SwiftPM executable. macOS may also require approval in **System Settings → General → Login Items**.

## Some process fields are unavailable

macOS restricts access to protected or other-user processes. ProcessWatch does not request root privileges. Empty command lines, paths, or working directories are expected for some processes.

## Gatekeeper warning

Ad-hoc signed local builds are for development. Public users should download a Developer ID-signed and notarized release. Do not remove quarantine metadata as a distribution workaround.
