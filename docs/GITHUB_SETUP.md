# GitHub Repository Setup

Use this checklist after creating the public repository.

## Repository metadata

- Description: `Local-first macOS process anomaly monitor for CPU, memory, disk I/O, process storms, and orphan processes.`
- Website: leave empty until a stable documentation or product page exists.
- Topics: `macos`, `swift`, `swiftui`, `menubar`, `process-monitor`, `system-monitor`, `developer-tools`, `open-source`.
- Upload `docs/assets/social-preview.png` as the repository social preview.

## Features

- Enable Issues.
- Enable Discussions if you want a place for usage questions.
- Enable private vulnerability reporting before announcing the repository.
- Disable the Wiki unless it will be actively maintained; keep canonical docs in the repository.

## Main branch protection

Recommended rules for `main`:

- Require a pull request before merging.
- Require the `CI / build` status check.
- Require conversations to be resolved.
- Block force pushes and branch deletion.
- Require linear history if using squash or rebase merges.
- Allow maintainers to bypass only for emergency security releases.

## Release environment

Create an environment named `macos-release`:

- Add one or more required reviewers.
- Restrict deployment to the `main` branch or version tags.
- Store release secrets in the environment rather than ordinary repository secrets when possible.

Required GitHub Actions secrets for `.github/workflows/release.yml`:

- `MACOS_CERTIFICATE_BASE64`
- `MACOS_CERTIFICATE_PASSWORD`
- `MACOS_KEYCHAIN_PASSWORD`
- `DEVELOPER_ID_APPLICATION`
- `APPLE_ID`
- `APPLE_TEAM_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`

## Security settings

- Enable secret scanning and push protection where available.
- Enable dependency graph; the current project has no third-party package dependency.
- Enable CodeQL default setup for Swift if available for the repository plan.
- Review Actions permissions and keep the default token read-only except in the release workflow.

## First release

The first public binary should remain a pre-release until it has been tested on both Apple silicon and Intel hardware. Attach only notarized DMG files and checksums. Source-only GitHub tags can be published earlier.

## Official references

- GitHub community profile: https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/about-community-profiles-for-public-repositories
- Swift CI: https://docs.github.com/actions/guides/building-and-testing-swift
- Repository best practices: https://docs.github.com/en/repositories/creating-and-managing-repositories/best-practices-for-repositories
