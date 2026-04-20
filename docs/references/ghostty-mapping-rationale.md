# Ghostty Mapping Rationale (Controller)

## Goal
Reduce cognitive load while using dictation + controller together by making button roles easy to remember.

## Layout Decisions
- `L1` (`leftShoulder`): split-focus cycle only (within current tab, `goto_split:next` / `Cmd+]`).
- `R1` (`rightShoulder`): tab cycle only.
- `Options`: close focused split only (`close_surface` / `Cmd+W`), not whole tab.
- `L2` (`leftTrigger`): hold `Command` as a modifier chord.
- `X`: send `Tab`, primarily as the `L2` companion for app switching (`Cmd+Tab`).
- `Y`: send `Backspace` in Ghostty as a quick correction key while typing.
- `Menu`: send `Shift+Tab` in Ghostty to toggle Codex Plan mode without typing `/plan`.
- Left thumbstick click: open a right split with the Codex repo picker (`codex_jump`).
- Right thumbstick click: open a right split and start Codex in the inherited current directory.
- D-pad `Up/Down`: global arrow-key navigation via `alwaysOn`.
- D-pad `Left/Right`: Ghostty-only zoom out/in.
- Right stick up: open `/model`.
- Right stick horizontal tilt: Ghostty-only punctuation shortcuts (`Left` = `/`, `Right` = `$`).
- `Share`: run the shared Ghostty picker-tab helper so the new tab opens directly into the Codex jump picker.
- `Options`, `L1`, and `R1` use Ghostty native actions instead of synthetic macOS keystrokes.

## Why This Layout
- Shoulder buttons become role-based instead of direction-based:
  - one shoulder for tabs, one shoulder for splits.
- `X` becomes a lightweight companion key instead of a destructive or layout-changing action.
- `Y` is reserved for text correction because Backspace is common during dictated terminal input.
- `Menu` toggles Codex Plan mode through its native keyboard shortcut instead of injecting slash-command text into the composer.
- `L2` + `X` is a low-risk modifier experiment because it uses a held modifier with a discrete button, not an analog stick.
- The D-pad keeps high-value global vertical navigation while using the low-use horizontal directions for Ghostty zoom.
- The right stick now carries the quick Codex-specific prompts without consuming face buttons:
  - up is `/model`
  - horizontal tilt is punctuation
- New tabs and splits now intentionally diverge:
  - new tab means "start somewhere else" and should open the repo chooser immediately.
  - left thumbstick split means "choose a repo in a neighboring pane".
  - right thumbstick split means "stay in this workspace" and should start Codex in the inherited current directory.
- Core Ghostty navigation/management buttons now target Ghostty actions directly so they do not depend on separate keybinding definitions staying in sync.

## Notes
- `L2`, `X`, `R2`, D-pad up/down arrows, and left-stick vertical scroll are configured in the top-level `alwaysOn` section.
- Mapping changes hot-reload from `config/mappings.json`; restart is not required for config-only changes.
- If Ghostty keybindings change, update descriptions and keycodes together in `config/mappings.json`.
- The `Share` behavior depends on Ghostty `1.3.0+` native AppleScript support and currently uses Ghostty's preview scripting API through a shared helper script.
- We intentionally accept that dependency because Ghostty-native actions cover the simple terminal structure controls, while AppleScript is reserved for the richer new-tab startup flow.
