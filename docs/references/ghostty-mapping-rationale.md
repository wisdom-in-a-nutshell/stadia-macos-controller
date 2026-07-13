# Ghostty Mapping Rationale (Controller)

## Goal
Reduce cognitive load while using dictation + controller together by making button roles easy to remember.

## Source Of Truth
`config/mappings.json` owns the exact current layout: button names, keycodes, modifiers, helper commands, debounce values, and action descriptions. Keep this page focused on layout intent so it does not drift from the config.

## Layout Principles
- Shoulder buttons use a paired previous/next model, scoped to the active app:
  - In Ghostty, L1/R1 move to the previous/next tab.
  - In the Codex app, L1/R1 invoke the native View menu's Previous Task/Next Task commands. This avoids Codex's overlapping task and browser-tab keyboard shortcuts.
- Codex app commands use native menu actions when Codex exposes them. New Task, sidebar toggles, zoom, and previous/next task therefore do not depend on keyboard shortcuts remaining stable across app updates.
- Literal input controls remain keystroke- or text-based: composer text, Enter, Escape, Backspace, Ctrl+C, and the held Control modifier. Archive and Plan mode also remain shortcut-based because Codex does not expose native menu commands for them.
- Face buttons are reserved for high-frequency terminal input and correction, not layout-changing actions.
- The menu-style center button is reserved for Codex mode changes through native keyboard shortcuts rather than injected slash-command text.
- The held-trigger modifier chord remains experimental; it should stay low-risk and avoid destructive combinations.
- The D-pad keeps high-value global vertical navigation while using the low-use horizontal directions for Ghostty zoom.
- The right stick carries quick Codex-specific prompt or punctuation actions without consuming face buttons.
- New tabs and splits now intentionally diverge:
  - new tab means "start somewhere else" and should open the repo chooser immediately.
  - left thumbstick split means "choose a repo in a neighboring pane".
  - right thumbstick split means "stay in this workspace" and should start Codex in the inherited current directory.
- Core Ghostty navigation, management, and zoom buttons target Ghostty actions directly where available so they do not depend on separate keybinding definitions staying in sync.

## Notes
- Mapping changes hot-reload from `config/mappings.json`; restart is not required for config-only changes.
- If Ghostty keybindings change, update descriptions and keycodes together in `config/mappings.json`.
- Some Codex surface behavior depends on Ghostty `1.3.0+` native AppleScript support and currently uses Ghostty's preview scripting API through shared helper scripts.
- We intentionally accept that dependency because Ghostty-native actions cover the simple terminal structure controls, while AppleScript is reserved for the richer new-tab startup flow.
