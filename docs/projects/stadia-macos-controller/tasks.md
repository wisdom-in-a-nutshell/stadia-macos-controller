# Stadia macOS Controller

## Goal
Create a reliable local controller bridge that maps Stadia button presses to macOS shortcuts, with app-specific behavior for Ghostty first.

## Why / Impact
Using the controller as a shortcut pad reduces keyboard context switching and enables faster terminal control.
Primary beneficiary is the local developer workflow, especially Ghostty tab switching and voice-trigger actions.
If implemented poorly, it could trigger unintended keypresses globally and become disruptive.

## Context
A Stadia controller is now detected on this macOS machine via USB (`18d1:9400`) and visible in Apple GameController APIs as an extended gamepad profile.
This repository is newly created to hold the bridge service, config, and run instructions.

## Decisions
Use Swift + Apple GameController as the first implementation path to avoid external runtime dependencies.
Implement app-scoped mappings through a simple config layer so Ghostty behavior can be tuned without code rewrites.

## Open Questions
None.

## Tasks
- [ ] Scaffold CLI app (`src/`) that detects Stadia controller connection/disconnection and logs button events.
- [ ] Implement mapping engine for button -> action with debounce and edge-trigger behavior.
- [ ] Implement macOS action executor for keyboard shortcuts and shell commands.
- [ ] Add app-focused rules (Ghostty first) and a default mapping config file.
- [ ] Add run scripts and setup notes for Accessibility permissions.
- [ ] Validate end-to-end behavior with Ghostty tab shortcuts and at least one non-Ghostty action.
- [ ] Review `AGENTS.md` and update if new repeatable patterns were introduced.
- [ ] Archive project notes to `docs/projects/archive/stadia-macos-controller/` when the user confirms completion.

## Validation / Test Plan
Run the bridge locally with controller connected.
Press mapped buttons and verify expected shortcut/command fires only once per button press.
Verify Ghostty tab navigation actions perform correctly when Ghostty is focused.

## Progress Log
- 2026-02-26: [DONE] Created repository skeleton and initial project task tracker.

## Next 3 Actions
1. Scaffold the Swift controller listener and print button event names.
2. Add a minimal action dispatcher for one Ghostty shortcut and one shell command.
3. Test live button presses and tune debounce defaults.
