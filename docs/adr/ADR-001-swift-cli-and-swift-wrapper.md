# ADR-001: Use A Swift CLI Core And A Swift macOS Wrapper

## Status

Accepted

## Context

The product started as a single shell script that manages `pmset` settings for a plugged-in Mac. The launch requirement is to keep the product extremely light, add a minimal visual application with toggles and sliders, and avoid installing outside dependencies if possible.

The early plan was to keep a shell core and layer a native wrapper on top. The user then explicitly redirected the implementation to Swift. That changed the decision criteria: the system still needs to stay CLI-first and light, but the engine and wrapper now need a single language and stronger typed contracts.

## Decision

Keep the command engine CLI-first, but rewrite it in Swift and make it the source of truth for power-state behavior. Add a minimal Swift macOS wrapper that calls the CLI for reads and writes.

Implementation details:

- the Swift CLI owns `pmset` reads, writes, restore logic, monitor lifecycle, and state files
- the Swift app owns presentation, user input, and privilege prompts
- the app uses ordinary `Process` execution for non-privileged reads
- the app uses AppleScript `administrator privileges` for privileged writes
- installation ships both the CLI and the app together

## Consequences

### Easier

- the product stays tiny and easy to reason about
- the CLI contract stays transparent and scriptable
- installation can stay script-first and dependency-free
- debugging remains possible entirely from Terminal

### Harder

- the app and CLI must agree on argument contracts and JSON output
- Apple toolchain health matters more than it did in the shell version
- privilege escalation logic lives outside the CLI's current `sudo` flow

### Accepted trade-off

The product is a local utility, not a platform. A Swift CLI plus a thin Swift app is the cleanest way to satisfy the user’s direction without bloating the product.
