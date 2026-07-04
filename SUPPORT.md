# Support

Use GitHub Issues for reproducible bugs and feature proposals. Use GitHub Discussions, if enabled, for general questions.

Before opening a bug:

```bash
./doctor.sh
./scripts/source_check.sh
./build.sh --clean
```

For a build failure, attach the relevant part of:

```text
build/swift-build.log
```

You can extract compiler diagnostics with:

```bash
grep -n -A 8 -B 8 "error:" build/swift-build.log
```

Redact usernames, home-directory paths, command-line arguments, repository names, credentials, and any private data before posting logs or screenshots.

Security-sensitive issues must follow [SECURITY.md](SECURITY.md), not the public issue tracker.
