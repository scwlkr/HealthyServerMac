# Launch Risks

## Current Blocker

This local machine cannot complete a Swift build that imports `Foundation` or `AppKit` because the installed Swift compiler and the installed Apple SDK do not match.

Observed issue:

- compiler: Apple Swift `6.2.4`
- SDK interfaces: Apple Swift `6.2.3`

Result:

- local `swiftc` builds fail before user code can be fully compiled
- local app verification is blocked

## What Is Still Verified Locally

- repository structure
- shell script syntax for installer and build scripts
- smoke checks for the source tree and release plumbing

## Launch Mitigation

1. Use GitHub-hosted macOS CI to build the CLI and app.
2. Publish release assets from tags.
3. Prefer release asset install in `install.sh`.
4. Treat this machine as a docs-and-source authoring environment until the Apple toolchain is repaired.

## Local Fix Options

1. Update Command Line Tools to a matching release.
2. Install full Xcode and switch the active developer directory.
3. Use a matching Apple Swift toolchain for the installed SDK.

## Release Decision

The repository is ready for source review and CI-backed release preparation, but this specific machine is not a reliable final build machine until the Apple toolchain mismatch is fixed.
