# Release Checklist

## Code and behavior

- [ ] Version and changelog updated
- [ ] `make check` passes
- [ ] Native and universal builds pass
- [ ] Apple silicon smoke test completed
- [ ] Intel smoke test completed or limitation disclosed
- [ ] Idle overhead measured
- [ ] CPU, memory, disk, storm, and repo-harness alerts exercised
- [ ] Quit, relaunch, login item, and notification behavior tested
- [ ] Process termination confirmation tested only on disposable processes

## Privacy and security

- [ ] Privacy policy matches current behavior
- [ ] Privacy manifest reviewed
- [ ] No secrets or certificates in Git history
- [ ] Private vulnerability reporting enabled
- [ ] Release environment protected
- [ ] Diagnostics and screenshots redacted

## Distribution

- [ ] Universal binary verified with `lipo -archs`
- [ ] Developer ID signature verified
- [ ] Hardened Runtime enabled
- [ ] App notarized and stapled
- [ ] DMG notarized and stapled
- [ ] Gatekeeper assessment passes on clean Mac
- [ ] SHA-256 checksums generated
- [ ] Release notes include known limitations
- [ ] Beta/pre-release status selected when appropriate
