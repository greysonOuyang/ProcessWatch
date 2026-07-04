# Contributing

Thank you for improving ProcessWatch.

## Development setup

```bash
./doctor.sh
./scripts/source_check.sh
./build.sh --clean --run
```

Open `Package.swift` in Xcode for interactive development.

## Pull request expectations

- Keep monitoring overhead low and measurable.
- Prefer public macOS APIs. Any private or reverse-engineered API requires explicit discussion.
- Do not add telemetry, analytics, or network transmission without an approved privacy design.
- Preserve graceful behavior when process metadata is inaccessible.
- Confirm destructive process actions with the user; do not add automatic killing.
- Update user-facing documentation and `CHANGELOG.md` for material changes.
- Add or extend checks for bug fixes where practical.

## Coding style

- Follow standard Swift naming and API design conventions.
- Keep sampling, anomaly detection, storage, and UI concerns separated.
- Avoid blocking the main actor with process enumeration or filesystem work.
- Treat cumulative kernel counters as monotonic but handle PID reuse and counter reset.
- Use explicit units in model and setting names.

## Commit and PR scope

Prefer focused commits and one concern per pull request. Explain behavior changes, performance impact, validation performed, and any macOS-version limitations.

By contributing, you agree that your contribution is licensed under the project's MIT License.
