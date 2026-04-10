# Launch Risks

## Resolved Toolchain Issue

The earlier local Swift build blocker is resolved.

Current working setup:

- active developer directory: `/Applications/Xcode.app/Contents/Developer`
- Xcode: `26.4`
- Swift: `6.3`

One implementation note remains:

- build scripts pass the active macOS SDK explicitly with `-sdk "$(xcrun --show-sdk-path)"` because this machine would not compile reliably without it

That is now handled in the repository scripts.

## What Was Verified Locally

- `./scripts/build-cli.sh`
- `./scripts/build-app.sh`
- `./scripts/package-release.sh`
- `./install.sh --bin-dir <tmp> --app-dir <tmp>`
- `./dist/buoy doctor`
- `./dist/buoy status --json`
- `./dist/buoy apply --dry-run ...`
- `bash -n install.sh scripts/*.sh buoy`
- `./scripts/smoke-test.sh`

## Remaining Risks

### Privileged system changes

Real `apply` and `off` operations still depend on standard macOS administrator authentication and actual `pmset` behavior on the target machine.

### Closed-lid helper lifecycle

Closed-lid mode depends on a helper PID. If that helper is killed externally, the app and CLI will report the drift, but the user still has to reapply the mode.

### Distribution trust

If the remote installer uses release assets, the GitHub release must stay in sync with the source branch and tags.

## Release Position

There is no remaining local build blocker in this repository. The product is ready for CI-backed release preparation and final launch validation on a target machine where privileged mode changes can be exercised for real.
