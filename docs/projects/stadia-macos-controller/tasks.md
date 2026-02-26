# Stadia macOS Controller

## Goal
Build a reliable local macOS controller bridge that maps Stadia button presses to actions, with automatic profile switching by frontmost app and a strong default profile for Ghostty + Codex workflows.

## Why / Impact
Using the Stadia controller as a shortcut pad reduces keyboard context switching and supports a dictation-first workflow where button taps trigger common editing, terminal, and voice-assist actions.
Primary beneficiary is day-to-day development in Ghostty/Codex; secondary value is reusable per-app profiles for other tools.
If implemented poorly, global hotkeys could fire in the wrong app and disrupt active work.

## Context
The Stadia controller is detected on this macOS machine via USB (`18d1:9400`) and appears in Apple GameController APIs as an extended gamepad profile.
This repo currently contains planning/docs only; runtime code has not been scaffolded yet.
The desired behavior is profile-based: when the frontmost app changes, action mappings should switch automatically (Ghostty and Codex first).
The user often dictates commands/prompts, so button mappings should prioritize quick tap/hold actions that complement voice input.

## Decisions
Use Swift + Apple `GameController` for controller input capture.
Use Apple AppKit/Accessibility APIs for frontmost-app awareness and action execution so behavior remains native on macOS.
Implement a single source-of-truth config layer for profile mappings (not hardcoded in multiple places).
Start with two concrete profiles: `ghostty` and `codex`, plus a safe `default` fallback profile.
Support edge-trigger (press once), hold-repeat (optional), and debounce controls per mapping.

## Open Questions
Should Codex-specific mappings target the Codex terminal app only, browser-based Codex, or both?
What is the preferred config format for user-edited mappings (`.json` vs `.yaml`)?
Which button(s) should be reserved as a global emergency disable toggle?

## Tasks
- [ ] Scaffold Swift CLI app in `src/` with controller connection/disconnection logging and per-button event logging.
- [ ] Add input event normalization layer (`button`, `state`, `timestamp`, `repeat`) so mapping logic is controller-model agnostic.
- [ ] Build profile resolver that tracks frontmost app bundle identifier and selects active profile (`ghostty`, `codex`, `default`).
- [ ] Implement mapping engine with per-action debounce, edge-trigger semantics, and optional hold behavior.
- [ ] Implement action executors for: keyboard shortcuts, shell commands, and optional AppleScript commands.
- [ ] Add config loader/watcher for profile mappings in `config/mappings.json` (or chosen format) with schema validation.
- [ ] Define initial Ghostty profile for high-frequency actions (tab navigation, split/nav, command palette, etc.).
- [ ] Define initial Codex profile for dictation-adjacent actions (push-to-talk trigger, quick edit/navigation shortcuts, confirm/send patterns).
- [ ] Add global safety controls: dry-run mode, per-profile enable/disable, and emergency toggle/hotkey.
- [ ] Add startup/run scripts and setup notes for required permissions (Accessibility/Input Monitoring if required).
- [ ] Validate end-to-end: switch between Ghostty and Codex, press mapped buttons, verify correct app-specific action only fires once.
- [ ] Validate fallback behavior when frontmost app has no profile (`default` profile applies, no unexpected global action).
- [ ] Review `AGENTS.md` and update if new repeatable implementation patterns were introduced.
- [ ] Archive project notes to `docs/projects/archive/stadia-macos-controller/` when the user confirms completion.

## Validation / Test Plan
Run bridge locally with Stadia controller connected.
Open Ghostty and Codex targets, then alternate focus while pressing the same button to confirm profile-based behavior changes correctly.
Verify debounce prevents accidental double-fire during quick taps.
Verify emergency toggle immediately suppresses all mapped actions.
Run in dry-run mode first to inspect resolved profile + action logs before enabling real key/command execution.

## Progress Log
- 2026-02-26: [DONE] Created repository skeleton and initial project task tracker.
- 2026-02-26: [DONE] Refined plan for frontmost-app profile switching with Ghostty/Codex-first scope.

## Next 3 Actions
1. Scaffold the Swift listener and print normalized button events with controller metadata.
2. Implement frontmost-app detection and active-profile resolution for `ghostty`, `codex`, and `default`.
3. Wire one Ghostty shortcut and one Codex action in dry-run mode, then test live profile switching.
