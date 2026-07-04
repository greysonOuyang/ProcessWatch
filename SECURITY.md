# Security Policy

## Supported versions

Only the latest tagged release receives security fixes during the beta period.

## Reporting a vulnerability

Before making the repository public, enable **GitHub private vulnerability reporting** under **Settings → Security → Code security and analysis**.

After it is enabled, report vulnerabilities through the repository's **Security → Report a vulnerability** flow. Do not open a public issue for vulnerabilities involving arbitrary code execution, privilege boundaries, command-line disclosure, unsafe process termination, release-signing credentials, or notarization secrets.

A useful report includes:

- affected ProcessWatch version and commit;
- macOS version and hardware architecture;
- reproduction steps;
- security impact;
- whether the issue requires local access or elevated privileges;
- a minimal proof of concept, with sensitive data redacted.

## Release security

- Never commit Developer ID certificates, private keys, app-specific passwords, or notary credentials.
- Use a Keychain profile for `notarytool` locally.
- Store CI signing material only as encrypted repository or environment secrets.
- Protect release environments with required reviewers.
- Publish SHA-256 checksums for binary releases.

## Scope

ProcessWatch intentionally runs without root privileges. Requests to add privilege escalation, kernel extensions, hidden process access, or automatic force-killing require a separate security design review.

## Process actions and cleanup scripts

ProcessWatch excludes PID 1 and its own PID from termination operations. Group
termination, orphan-only termination, high-CPU-only termination, and force quit
all require explicit user confirmation and run with the current user's existing
permissions; the app never requests privilege escalation.

The app does not implement a generic memory purge or automatic cache deletion.
The “custom cleanup script” action only launches a file the user manually selects
and confirms, using `/bin/zsh` and the selected process group's working directory
when available. Treat such scripts as arbitrary code and review them before use.


## Action history and scripts

Action history is a local diagnostic log and may contain executable paths. Users should inspect exported JSON before sharing it. ProcessWatch never auto-runs a cleanup script: the user must select the file, review a confirmation dialog, and accept execution. Scripts run without privilege escalation.
