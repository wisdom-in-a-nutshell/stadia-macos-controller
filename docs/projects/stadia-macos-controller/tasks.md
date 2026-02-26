# Stadia macOS Controller

## Goal
Build a reliable local macOS controller bridge that maps Stadia button presses to actions, with automatic profile switching by frontmost app and a strong Phase 1 profile for Ghostty.

## Why / Impact
Using the Stadia controller as a shortcut pad reduces keyboard context switching and supports a dictation-first workflow where button taps trigger common editing, terminal, and voice-assist actions.
Primary beneficiary is day-to-day development in Ghostty; secondary value is reusable per-app profiles for later expansion.
If implemented poorly, global hotkeys could fire in the wrong app and disrupt active work.

## Context
The Stadia controller is detected on this macOS machine via USB (`18d1:9400`) and appears in Apple GameController APIs as an extended gamepad profile.
This repo currently contains planning/docs only; runtime code has not been scaffolded yet.
The desired behavior is profile-based: when the frontmost app changes, action mappings should switch automatically.
Phase 1 only requires a `ghostty` profile plus a safe `default` fallback; additional app profiles come later.
The user often dictates commands/prompts, so button mappings should prioritize quick tap/hold actions that complement voice input.

## Decisions
Use Swift + Apple `GameController` for controller input capture.
Use Apple AppKit/Accessibility APIs for frontmost-app awareness and action execution so behavior remains native on macOS.
Implement a single source-of-truth config layer for profile mappings (not hardcoded in multiple places).
Start with one concrete profile: `ghostty`, plus a safe `default` fallback profile.
Support edge-trigger (press once), hold-repeat (optional), and debounce controls per mapping.

## Open Questions
None for current implementation.

## Tasks
- [x] Scaffold Swift CLI app in `src/` with controller connection/disconnection logging and per-button event logging.
- [x] Add input event normalization layer (`button`, `state`, `timestamp`, `repeat`) so mapping logic is controller-model agnostic.
- [x] Build profile resolver that tracks frontmost app bundle identifier and selects active profile (`ghostty`, `default`).
- [x] Implement mapping engine with per-action debounce, edge-trigger semantics, and optional hold behavior.
- [x] Implement action executors for: keyboard shortcuts, shell commands, and optional AppleScript commands.
- [x] Add config loader with schema validation for profile mappings in `config/mappings.json`.
- [ ] Add config file watcher for hot-reload updates without restarting the bridge.
- [x] Define initial Ghostty profile for high-frequency actions (tab navigation, split/nav, command palette, etc.).
- [x] Add global safety controls: dry-run mode, per-profile enable/disable, and emergency toggle/hotkey.
- [x] Add startup/run scripts and setup notes for required permissions (Accessibility/Input Monitoring if required).
- [ ] Validate end-to-end: focus Ghostty, press mapped buttons, verify expected action fires only once per press.
- [ ] Validate fallback behavior when frontmost app has no profile (`default` profile applies, no unexpected global action).
- [ ] Capture Phase 2 backlog for Codex-specific profile behavior after Ghostty flow is stable.
- [x] Review `AGENTS.md` and update if new repeatable implementation patterns were introduced (no new repo-local rule needed yet).
- [ ] Archive project notes to `docs/projects/archive/stadia-macos-controller/` when the user confirms completion.

## Validation / Test Plan
Run bridge locally with Stadia controller connected.
Open Ghostty and verify mapped button behavior for core flows (navigation, tab movement, command triggers).
Move focus to a non-profiled app and verify no Ghostty-specific action leaks.
Verify debounce prevents accidental double-fire during quick taps.
Verify emergency toggle immediately suppresses all mapped actions.
Run in dry-run mode first to inspect resolved profile + action logs before enabling real key/command execution.

## Progress Log
- 2026-02-26: [DONE] Created repository skeleton and initial project task tracker.
- 2026-02-26: [DONE] Added frontmost-app profile-switching architecture to the plan.
- 2026-02-26: [DONE] Re-scoped Phase 1 to Ghostty-only per user direction; Codex deferred to Phase 2.
- 2026-02-26: [DONE] Implemented first runnable Swift CLI bridge (`Package.swift`, `src/main.swift`) with controller events, profile resolution, debounce, and action execution.
- 2026-02-26: [DONE] Added starter mappings and safety defaults in `config/mappings.json` (Ghostty + default profiles, dry-run on, emergency toggle button).
- 2026-02-26: [DONE] Added run/setup docs and script (`scripts/run-bridge.sh`, `docs/architecture/bridge-overview.md`, `docs/references/mappings-schema.md`, `docs/references/setup.md`).
- 2026-02-26: [DONE] Added robust input polling and background monitoring (`GCController.shouldMonitorBackgroundEvents=true`) to fix missing button events.
- 2026-02-26: [DONE] Added optional `codex` profile defaults (`com.openai.codex`) including `A` hold-space behavior (`holdKeystroke`) and `B` enter.

## Next 3 Actions
1. Run the bridge with controller connected and verify button event logs plus profile resolution in dry-run mode.
2. Validate live mode (`--no-dry-run`) with Accessibility permission and confirm Ghostty split action behavior.
3. Add config hot-reload watcher so mapping edits apply without restarting the process.
