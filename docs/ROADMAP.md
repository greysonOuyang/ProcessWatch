# Roadmap

## Before stable 1.0

- Validate sampling accuracy on multiple Intel and Apple silicon Macs.
- Add automated tests around grouping, PID reuse, cooldown, and anomaly state transitions.
- Measure ProcessWatch's own idle CPU, wakeups, memory, and disk activity.
- Add English UI localization while preserving Simplified Chinese.
- Add an explicit first-launch explanation before requesting notification permission.
- Add safe diagnostic export with automatic redaction.
- Complete signed/notarized release testing through GitHub Actions or a dedicated release Mac.
- Document false-positive guidance for compilers, browsers, media encoders, and developer agents.

## Possible later work

- Per-rule profiles and battery-only thresholds.
- Optional process tree visualization.
- Historical charts with strict retention limits.
- Network activity sampling using public APIs.
- Sparkle or another signed update mechanism after a security review.
- Exportable anonymized incident reports.

## Explicitly out of scope for now

- Root helper or privileged daemon.
- Kernel extension or Endpoint Security client.
- Automatic process killing.
- Memory-cleaning claims.
- Private SMC APIs for fan control.
- Remote monitoring or telemetry.
