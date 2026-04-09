# HealthyServerMac

`healthyservermac` is a small macOS command-line toggle for putting a plugged-in MacBook into a "server-like" power profile and then restoring the previous AC settings later.

The goal is narrow on purpose:

- keep the Mac awake on AC power
- let the display sleep normally
- keep network/TTY-friendly behavior for remote access
- avoid invasive power changes that are hard to reason about later

## Files

- `healthyservermac` — main CLI
- `README.md` — design notes, usage, and tradeoffs

## Quick Start

Run it directly from this folder:

```bash
./healthyservermac on
./healthyservermac on -clam
./healthyservermac status
./healthyservermac off
./healthyservermac screen-off
./healthyservermac path-add
```

If you want a global command, install the symlink:

```bash
./healthyservermac install
healthyservermac on
healthyservermac on -clam
```

The default install target is the first writable directory on your `PATH` (commonly `/usr/local/bin` or `~/.local/bin`). You can override it:

```bash
./healthyservermac install --target-dir ~/bin
```

## What "On" Does

When you run `healthyservermac on`, the script reads your current **AC power** settings with `pmset`, saves the values it is about to change, and then applies a server-oriented AC profile.

It currently manages these settings when they are available on your Mac:

- `sleep=0`
- `displaysleep=10` by default, or your `--display-sleep` value
- `standby=0`
- `powernap=0`
- `womp=1`
- `ttyskeepawake=1`
- `tcpkeepalive=1`

That combination is meant to keep the machine doing work while plugged in, allow the display to turn off, and keep remote access behavior sane.

## Closed-Lid Mode

If you run:

```bash
healthyservermac on -clam
```

the tool keeps the existing AC profile behavior above and also enables a closed-lid helper.

That helper watches the current power state and sets `pmset disablesleep` like this:

- `SleepDisabled=1` while the Mac is on AC power
- `SleepDisabled=1` while on battery above 25%
- `SleepDisabled=0` once battery falls to 25% or lower, unless it was already enabled before you turned this mode on

The original `SleepDisabled` value is saved and restored when you run `healthyservermac off`.

The battery threshold and poll interval are configurable:

```bash
HEALTHYSERVERMAC_CLAM_MIN_BATTERY=30 healthyservermac on -clam
HEALTHYSERVERMAC_CLAM_POLL_SECONDS=10 healthyservermac on -clam
```

## What "Off" Does

When you run `healthyservermac off`, the script restores the saved AC values from the last time you enabled the mode.

The saved state lives at:

```text
~/.healthyservermac/ac-settings.state
```

You can override that location with `HEALTHYSERVERMAC_STATE_DIR`.

## Commands

```bash
healthyservermac on
healthyservermac on -clam
healthyservermac on --display-sleep 5
healthyservermac off
healthyservermac status
healthyservermac install
healthyservermac screen-off
healthyservermac install --target-dir /usr/local/bin
healthyservermac path-add
```

You can preview any write operation without changing the machine:

```bash
healthyservermac on --dry-run
healthyservermac off --dry-run
healthyservermac install --dry-run
```

## Screen Off

`healthyservermac screen-off` immediately triggers `pmset displaysleepnow`, turning the display dark while leaving the system awake. The display wakes again the usual way (mouse movement, keyboard press, lid open), so it cannot make the Mac unusable. Add `--dry-run` if you just want to see the command before running it.

## Path

`healthyservermac path-add` appends this repository to your default shell profile (`.zshrc`, `.bashrc`, etc.), so the script is immediately available everywhere without creating a separate symlink. Run it once, then restart your shell or `source` the profile to pick up the new `PATH`.

## Design Notes

This is the reasoning behind the implementation:

### 1. `pmset` first, helper only when needed

`caffeinate` is great for temporary assertions, but the base server-mode behavior here is closer to a persistent operating mode. `pmset` is a better fit because:

- it survives reboots
- the default `on` mode does not require a background helper process to stay alive
- it maps directly onto the macOS power settings you would otherwise change manually

The only exception is `-clam`, which needs a small helper loop because the battery threshold rule is dynamic.

### 2. AC-only changes

This script uses `pmset -c`, which means it only changes the charger/AC profile. That keeps the behavior intentionally scoped to the "always plugged in" scenario instead of accidentally forcing server-like wakefulness on battery.

### 3. Restore what was there before

The script does not blindly "reset to defaults." It saves the current AC values it is about to change and re-applies those exact values on `off`.

That is safer than assuming your machine started from stock defaults.

### 4. Avoid risky sleep internals

I did **not** change things like:

- `hibernatemode`
- `hibernatefile`
- low-level unsupported sleep internals

Those can have side effects that are not worth the complexity for a simple server-mode toggle.

## Assumptions and Limits

- This is for **macOS only**.
- You will be prompted for `sudo` when the script changes power settings.
- This is designed for a Mac that is **plugged in most of the time**.
- Closed-lid awake mode is only enabled when you opt into `-clam`.
- The `-clam` helper is a background monitor process, so it does not survive a reboot. If you restart the Mac, run `healthyservermac off` to cleanly restore state and then enable it again if you still want that mode.
- It only manages the AC settings that are both supported by your machine and visible in the current `pmset` AC profile snapshot.

That last point is deliberate: it keeps the tool restore-safe instead of forcing settings it cannot reliably put back.

## Status Output

`healthyservermac status` prints:

- whether the mode is currently enabled according to the saved state file
- the current power source
- whether closed-lid mode is enabled and whether its helper is still running
- the current values of the AC settings this tool manages

## Suggested Workflow

For a machine you want to leave plugged in and reachable:

1. Run `healthyservermac on`
2. Leave the lid open
3. Let the display sleep on its own
4. Run `healthyservermac off` when you want normal AC behavior back

For closed-lid use:

1. Run `healthyservermac on -clam`
2. Close the lid only when the Mac is charging or above the configured battery threshold
3. Run `healthyservermac status` if you want to confirm the helper is active
4. Run `healthyservermac off` when you want to restore the original settings

## Future Extensions

If you want to take this further later, the next logical additions would be:

- launchd-based health checks or auto-reapply logic
- separate presets for "quiet server" vs "max performance"
- optional login/SSH sanity checks before enabling
- launchd-based persistence for `-clam`
