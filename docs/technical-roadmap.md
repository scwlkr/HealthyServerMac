# Technical Roadmap

## Product Direction

`Buoy` is a lightweight macOS utility for keeping a plugged-in Mac in a server-friendly power profile without hiding the underlying system behavior. The launch build should stay intentionally narrow:

- Swift CLI as the source of truth
- minimal native macOS app that speaks to the CLI
- no third-party runtime dependencies
- one-command install path through `curl | sh`

## Launch Naming

- Product: `Buoy`
- App bundle: `Buoy.app`
- CLI: `buoy`
- Legacy alias: `healthyservermac`

The public brand becomes shorter and easier to ship, while the legacy alias stays available for compatibility with the existing repository and any early users.

## Architecture Decision

### Option A: Keep the original shell engine

Pros:

- already works
- small runtime surface

Cons:

- weaker contracts for a native app
- harder to share models and validation
- lower confidence for launch polish

### Option B: Rewrite the engine in Swift and keep the app CLI-driven

Pros:

- one language for product logic and app code
- stronger machine-readable contracts
- easier state modeling and migration
- still preserves CLI-first operation

Cons:

- more implementation work than a shell wrapper
- local build quality now depends on Apple toolchain health

### Decision

Ship Option B. The product remains CLI-based, but the engine and the app move to Swift so the codebase is coherent and launch-grade.

## System Model

### Bounded Contexts

1. Power Profile Engine
   Reads current `pmset` state, applies the managed AC profile, and restores original values.

2. Closed-Lid Monitor
   Runs as an internal helper process to manage `SleepDisabled` while charging or above a battery floor.

3. State Store
   Persists original settings, current config, helper PID, and migration data from the legacy shell release.

4. Native Wrapper
   Provides the minimal visual control surface and uses CLI commands as its contract.

5. Distribution
   Builds the CLI, wraps the app bundle, installs both artifacts, and supports release packaging.

## Repo Topology

```text
.
├── README.md
├── install.sh
├── buoy
├── healthyservermac
├── PROGRESS_CHECKLIST.md
├── docs/
│   ├── technical-roadmap.md
│   ├── brand-system.md
│   ├── ux-foundation.md
│   ├── writing-style.md
│   └── adr/
│       └── ADR-001-swift-cli-and-swift-wrapper.md
├── Sources/
│   ├── BuoyCore/
│   ├── buoy/
│   └── BuoyApp/
├── scripts/
│   ├── build-cli.sh
│   ├── build-app.sh
│   ├── package-release.sh
│   ├── smoke-test.sh
│   └── uninstall.sh
└── .github/
    └── workflows/
        ├── ci.yml
        └── release.yml
```

## Implementation Roadmap

### Phase 1: Swift core

- model state as JSON instead of ad hoc flat files
- migrate from the legacy shell state file automatically
- add idempotent `apply`
- add `status --json` for the app
- keep `healthyservermac` as a compatibility alias

### Phase 2: Native macOS app

- ship a single-window AppKit app in Swift
- expose:
  - Server mode switch
  - Closed-lid switch
  - Display sleep slider
  - Battery floor slider
  - Poll interval slider
  - Appearance picker: system, light, dark
- execute privileged writes through AppleScript admin prompts
- execute reads through the CLI directly

### Phase 3: Distribution

- compile the CLI with `swiftc`
- compile the app executable with `swiftc` and wrap it into `Buoy.app`
- bundle the CLI inside the app resources
- install both `buoy` and `healthyservermac`
- keep the root install flow simple enough for `curl | sh`

### Phase 4: Launch polish

- release-ready README
- brand, UX, and writing guidance
- CI for source integrity and build steps
- release workflow for downloadable CLI and app assets

## State Design

State is local JSON because the product is local-only and narrow in scope.

### Stored fields

- `modeEnabled`
- `enabledAt`
- `config`
- `clamOriginalSleepDisabled`
- `clamMonitorPID`
- `originalValues`
- `configuredValues`

### Migration

If `~/.healthyservermac/ac-settings.state` exists and `~/.buoy/state.json` does not, the Swift state store imports the legacy keys and writes the new JSON shape automatically.

## Quality Targets

- zero third-party runtime dependencies
- CLI remains readable and auditable
- app surface stays minimal
- one-command install path
- safer restore path than apply path

## Risks And Mitigations

### Apple toolchain drift

Risk:
Local macOS SDK and Swift compiler versions can drift apart and block local builds.

Mitigation:
Ship direct build scripts, add CI on GitHub-hosted macOS, and publish release assets so end users do not depend on local toolchain quality.

### Privileged app writes

Risk:
The native app cannot depend on interactive `sudo`.

Mitigation:
Run privileged CLI writes through `osascript` admin prompts and keep non-privileged reads direct.

### Rename confusion

Risk:
The repo and the launch brand differ.

Mitigation:
Install the legacy alias during the first launch cycle and document the rename clearly.

## Launch Exit Criteria

- `buoy apply`, `off`, `status`, `doctor`, and `screen-off` are implemented
- `Buoy.app` is buildable in CI and release workflows
- `install.sh` installs both CLI and app
- the README is enough for a first-time user
- launch docs match the shipped code
