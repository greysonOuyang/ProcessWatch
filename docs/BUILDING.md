# Building

## Requirements

- macOS 13+
- Xcode 15+ or compatible Xcode Command Line Tools
- No Homebrew dependency

Verify the environment:

```bash
./doctor.sh
./scripts/source_check.sh
```

## Local build

```bash
./build.sh --clean --run
```

The default local build targets the current architecture and uses an ad-hoc signature.

Debug build:

```bash
./build.sh --debug --run
```

Unsigned build:

```bash
./build.sh --release --no-sign
```

Universal build:

```bash
./build.sh --release --universal
```

## Output

```text
dist/ProcessWatch.app
build/swift-build.log
```

## Install

Current user:

```bash
./scripts/install_app.sh
```

System-wide:

```bash
./scripts/install_app.sh --system
```

The installer does not remove Gatekeeper quarantine metadata. Public users should install a Developer ID-signed and notarized release.

## Common Xcode selection issue

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
xcrun swift --version
```

## Source package layout

```text
Package.swift
Sources/ProcessWatch/
Sources/ProcessWatchC/
Support/
Assets/
scripts/
```
