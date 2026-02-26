# Ghostty Mapping Rationale (Controller)

## Goal
Reduce cognitive load while using dictation + controller together by making button roles easy to remember.

## Layout Decisions
- `L1` (`leftShoulder`): tab cycle only.
- `R1` (`rightShoulder`): split-focus cycle only (within current tab, `goto_split:next` / `Cmd+]`).
- `X`: toggle split zoom (temporary maximize/restore for focused split).
- `D-pad Up/Down`: model picker up/down.
- `D-pad Left/Right`: intentionally unassigned for now.
- `Y`: intentionally unassigned for now.

## Why This Layout
- Shoulder buttons become role-based instead of direction-based:
  - one shoulder for tabs, one shoulder for splits.
- `X` is a safe high-value action (reversible, no close/delete side effects).
- Up/down movement uses the literal directional input (D-pad), improving legibility.
- Unassigned buttons are preserved as future capacity instead of forcing low-value mappings now.

## Notes
- Mapping changes hot-reload from `config/mappings.json`; restart is not required for config-only changes.
- If Ghostty keybindings change, update descriptions and keycodes together in `config/mappings.json`.
