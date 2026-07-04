# Open-Source and Release Audit

Audit date: 2026-07-03

## Ready in the repository

- MIT license and neutral contributor copyright.
- Bilingual README and beta-status disclosure.
- App icon in SVG, PNG, and ICNS formats.
- GitHub social preview image.
- Contribution, conduct, support, privacy, security, and disclaimer documents.
- Bug and feature issue forms plus pull-request template.
- macOS CI build and native logic checks.
- Version injection from a single `VERSION` file.
- Native and universal build modes.
- Developer ID signing with Hardened Runtime.
- Apple notarization and stapling script.
- Versioned DMG and SHA-256 checksums.
- GitHub Actions workflow for a protected, signed release.
- Privacy manifest and local-data documentation.
- Removal of quarantine-bypass behavior from the installer.
- Process termination protection for PID 1 and ProcessWatch itself.

## External actions still required

These cannot be completed inside the source archive:

1. Create the GitHub repository and select the final public owner/URL.
2. Confirm the bundle identifier is appropriate for that owner.
3. Enable GitHub private vulnerability reporting and branch protection.
4. Join the Apple Developer Program if not already enrolled.
5. Create a Developer ID Application certificate.
6. Configure notarization credentials and protected CI secrets.
7. Build on a real Mac using the selected Xcode version.
8. Test on Apple silicon and Intel hardware.
9. Measure the app's own idle CPU, wakeups, memory, and disk activity.
10. Run first-launch and Gatekeeper tests on a clean Mac user account.

## Release recommendation

Publish the repository immediately if desired, but publish binaries as `v1.3.0-beta.1` or another pre-release tag until the external validation above is complete. Do not label the binary as stable 1.0 yet.

## Logo assessment

A logo is appropriate because the app is distributed as a menu bar utility and needs a recognizable Finder, About panel, DMG, GitHub, and release identity. The included logo is original project artwork and is licensed with the repository.
