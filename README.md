# <img src="./buoy-icon.png" alt="Buoy icon" width="72" align="center" /> Buoy

<p align="center">
  Keep a plugged-in Mac server-ready with a small CLI and a native macOS control panel.
</p>

<p align="center">
  <strong>macOS only</strong> • <strong>CLI-first</strong> • <strong>Native app wrapper</strong>
</p>

## Why Buoy Exists

`Buoy` keeps a Mac in a server-friendly power profile without turning it into a background-heavy utility.

It is intentionally narrow:

- disable full idle sleep on AC
- let the display sleep normally
- keep wake-on-LAN and keepalive-friendly behavior
- restore the exact AC settings that were there before
- optionally manage closed-lid awake mode above a battery floor

## Quick Start

Remote install:

```bash
curl -fsSL https://raw.githubusercontent.com/scwlkr/HealthyServerMac/main/install.sh | bash
```

Local install from a clone:

```bash
./install.sh
```

The installer will:

- install `buoy`
- install the compatibility alias `healthyservermac`
- install `Buoy.app`
- prefer downloadable release assets when they exist
- fall back to a local source build when they do not

## CLI

Common commands:

```bash
buoy apply
buoy apply --display-sleep 5
buoy apply --clam --clam-min-battery 30 --clam-poll-seconds 15
buoy status
buoy status --json
buoy off
buoy screen-off
buoy doctor
```

Legacy alias:

```bash
healthyservermac apply
healthyservermac status
```

## App

`Buoy.app` is a minimal macOS wrapper around the CLI.

It exposes:

- Server mode switch
- Closed-lid switch
- Display sleep slider
- Battery floor slider
- Poll interval slider
- Appearance picker
- Apply, Turn Off, Sleep Display, and Refresh actions

Privileged writes run through the standard macOS admin prompt. Status reads come from the CLI directly.

## What `apply` Does

`buoy apply` reads the current AC power profile with `pmset`, saves the original values, and applies a server-oriented AC profile.

Managed settings:

- `sleep=0`
- `displaysleep=<minutes>`
- `standby=0`
- `powernap=0`
- `womp=1`
- `ttyskeepawake=1`
- `tcpkeepalive=1`

The restore point is preserved even if you run `apply` again with new values.

## Closed-Lid Awake Mode

When you add `--clam`, Buoy also manages `SleepDisabled`.

Behavior:

- `SleepDisabled=1` on AC power
- `SleepDisabled=1` on battery above the configured threshold
- `SleepDisabled=0` at or below the threshold unless it was already enabled before Buoy

Example:

```bash
buoy apply --clam --clam-min-battery 30 --clam-poll-seconds 10
```

## Restore Behavior

`buoy off` restores the original AC values saved the first time Buoy was applied, then stops the closed-lid helper and clears the current state.

Current Swift state file:

```text
~/.buoy/state.json
```

Legacy shell state files are migrated automatically from:

```text
~/.healthyservermac/ac-settings.state
```

## Build From Source

Build the CLI:

```bash
./scripts/build-cli.sh
```

Build the app:

```bash
./scripts/build-app.sh
```

Package release assets:

```bash
./scripts/package-release.sh
```

## Project Guides

- [Roadmap](docs/technical-roadmap.md)
- [Brand System](docs/brand-system.md)
- [UX Foundation](docs/ux-foundation.md)
- [Writing Style](docs/writing-style.md)
- [Launch Risks](docs/launch-risks.md)
- [Progress Checklist](PROGRESS_CHECKLIST.md)

## Limits

- macOS only
- privileged writes still depend on standard macOS admin authentication
- closed-lid mode uses a helper process
- local source builds require a healthy Apple Swift toolchain

## Launch Shape

The repo includes:

- direct Swift source for the CLI and app
- source build scripts
- release packaging script
- CI workflow
- release workflow

That is the launch shape: small CLI first, tiny native wrapper second, and no extra runtime dependencies.
