# Open-Source and Release Audit

Audit date: 2026-07-10

## Source-release status

ProcessWatch is ready for a public source release as a macOS public beta.

Repository readiness confirmed:

- MIT license with neutral contributor ownership.
- English and Simplified Chinese README files with beta-status disclosure.
- Original app branding in editable SVG, 1024 PNG, ICNS, documentation-logo, and social-preview formats.
- Contribution guide, code of conduct, support guide, privacy policy, security policy, issue forms, and pull-request template.
- Privacy manifest declaring no tracking or collected data.
- No third-party Swift package dependencies.
- Native logic checks, source validation, product review checks, and macOS CI.
- Single-source semantic versioning through `VERSION`.
- Native and universal build paths.
- Developer ID, Hardened Runtime, notarization, stapling, Gatekeeper verification, DMG packaging, and SHA-256 tooling.
- Runtime-only `.ai/` and `.repo-harness/` directories excluded from Git.
- Safety guards for PID 1 and the ProcessWatch process itself.

## Public binary gate

A source tag and GitHub source release may be published immediately. A downloadable DMG must not be presented as production-ready until all of the following are complete:

1. Build a universal arm64 + x86_64 application.
2. Sign the application and DMG with a valid Developer ID Application identity.
3. Enable Hardened Runtime and secure timestamping.
4. Notarize the application and DMG with Apple.
5. Staple and validate notarization tickets.
6. Pass Gatekeeper assessment on a clean macOS account.
7. Validate behavior on Apple silicon and Intel hardware.
8. Measure idle CPU, wakeups, memory, and disk activity over an extended run.
9. Publish SHA-256 checksums with the binary artifacts.

Ad-hoc signed local builds are development artifacts and must not be attached to a public release.

## Release recommendation

Publish `v1.5.2` as a GitHub pre-release with source archives only. Keep the project status as public beta. Add a notarized universal DMG to a later pre-release after the public binary gate is satisfied.

## Branding assessment

The refreshed icon uses a watchful eye as the primary silhouette, a process waveform as the diagnostic signal, and an amber badge for anomaly attention. The shape remains recognizable at Finder and menu-bar-adjacent sizes and is original project artwork distributed under the MIT License.
