# Buoy UX Foundation

## UX Goal

The app should feel like a native control surface for the CLI, not a separate product tier. The ideal user can understand the whole interface in under ten seconds.

## Window Structure

1. Header
   Product name and a one-line explanation.

2. Control Panel
   - Server mode switch
   - Closed-lid switch
   - Display sleep slider
   - Battery floor slider
   - Poll interval slider
   - Appearance picker
   - Apply, Turn Off, Sleep Display, Refresh buttons

3. Status Panel
   Current power source, battery, lid guard state, mode state, and monitor state.

4. Footer
   One sentence reminding the user that the CLI remains the source of truth.

## Interaction Rules

- `Apply` is explicit to avoid multiple admin prompts while dragging sliders.
- `Turn Off` is separate and high-clarity.
- `Refresh` always rehydrates state from the CLI.
- `Sleep Display` remains available without mode changes.
- Closed-lid control is disabled when Buoy mode is off.

## Appearance

### Layout

- single fixed window
- strong padding
- card-like grouped controls
- no sidebar
- no tabs

### Spacing

- outer padding: `24`
- card padding: `18`
- control gap: `14`
- section gap: `16`

### Typography

- title: `28pt`
- subtitle: `13pt`
- labels: `12-13pt`
- status block: `12pt mono`

## Accessibility

- appearance picker includes system mode by default
- all controls are keyboard reachable
- state labels are plain text, not color-only
- mono status block improves scanability without reducing clarity

## Naming Conventions

- `Server mode`
- `Closed-lid awake`
- `Display sleep`
- `Battery floor`
- `Poll interval`

These names are short enough for the window while still mapping to actual behavior.
