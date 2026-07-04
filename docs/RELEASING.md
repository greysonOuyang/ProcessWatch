# Releasing

Public macOS distribution outside the Mac App Store requires a deliberate signing and notarization workflow.

## One-time preparation

1. Join the Apple Developer Program.
2. Create and install a **Developer ID Application** certificate.
3. Create an app-specific password for the Apple account used for notarization.
4. Store notarization credentials in Keychain:

```bash
xcrun notarytool store-credentials ProcessWatchNotary \
  --apple-id 'you@example.com' \
  --team-id 'TEAMID' \
  --password 'app-specific-password'
```

5. Protect the certificate private key and never commit credentials.

## Version preparation

- Update `VERSION`.
- Add the release section to `CHANGELOG.md`.
- Confirm `README.md`, `PRIVACY.md`, and `SECURITY.md` remain accurate.
- Run the app on Apple silicon and Intel hardware if available.
- Run:

```bash
./doctor.sh
./scripts/source_check.sh
./build.sh --clean --release --universal
```

## Signed and notarized release

```bash
export DEVELOPER_ID_APPLICATION='Developer ID Application: Your Name (TEAMID)'
export NOTARY_PROFILE='ProcessWatchNotary'
./scripts/release.sh
```

The script:

1. requires a clean Git working tree unless explicitly overridden;
2. builds arm64 and x86_64 binaries;
3. combines them into one universal executable;
4. signs the app with Hardened Runtime and a secure timestamp;
5. submits a ZIP for notarization and staples the app;
6. creates and signs a DMG;
7. notarizes and staples the DMG;
8. runs Gatekeeper assessments;
9. writes SHA-256 checksums.

Expected output:

```text
dist/ProcessWatch.app
dist/ProcessWatch-<version>.dmg
dist/SHA256SUMS.txt
```

## GitHub release

- Create an annotated tag such as `v1.3.0`.
- Use the corresponding `CHANGELOG.md` section as release notes.
- Upload the DMG and `SHA256SUMS.txt`.
- Mark beta releases as pre-release.
- Do not upload ad-hoc signed local builds as official binaries.

## Verification on a clean Mac

```bash
spctl --assess --type execute --verbose=4 /Applications/ProcessWatch.app
codesign --verify --deep --strict --verbose=2 /Applications/ProcessWatch.app
xcrun stapler validate /Applications/ProcessWatch.app
```

Test first launch, notification permission, login item registration, process inspection, alert history, quit behavior, and relaunch after reboot.

## Mac App Store

The current project is designed for direct distribution and is not prepared for Mac App Store sandboxing. Process inspection capabilities and the custom SwiftPM packaging workflow require a separate feasibility review before an App Store submission.

## Official references

- Apple notarization: https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution
- Developer ID: https://developer.apple.com/developer-id/
- GitHub signing certificates in Actions: https://docs.github.com/actions/deployment/deploying-xcode-applications/installing-an-apple-certificate-on-macos-runners-for-xcode-development
