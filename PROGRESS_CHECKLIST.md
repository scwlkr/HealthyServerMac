# Launch Progress Checklist

## Architecture

- [x] Audit the existing repository and runtime behavior.
- [x] Choose the target product shape: Swift CLI core plus native macOS wrapper.
- [x] Write the technical roadmap and primary architecture decision record.
- [x] Restructure the repository into source, scripts, docs, and release assets.

## CLI Engine

- [x] Rewrite the engine as a Swift CLI entrypoint.
- [x] Fix state handling edge cases and idempotent apply behavior.
- [x] Add machine-readable status output for the macOS app.
- [x] Preserve a legacy `healthyservermac` alias for compatibility.

## Native App

- [x] Build the minimal Swift macOS app with toggles and sliders.
- [x] Add a light/dark/system appearance control.
- [x] Wire the app to the CLI through native privilege prompts.
- [x] Package the app as a local `.app` bundle with no external dependencies.

## Distribution

- [x] Add `install.sh` for local or `curl | sh` installation.
- [x] Add build and uninstall scripts.
- [x] Add CI smoke checks for the CLI, app build, and installer.

## Brand And UX

- [x] Finalize the public product name and naming rules.
- [x] Define the visual system, copy style, and technical writing style.
- [x] Rewrite the README for installation, usage, and launch polish.
- [x] Add brand and UX foundation docs.

## Verification

- [x] Run shell syntax checks.
- [ ] Build the macOS app locally.
- [ ] Run CLI smoke tests.
- [x] Record final launch risks and handoff notes.
