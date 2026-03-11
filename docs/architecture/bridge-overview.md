# Bridge Overview

## Phase 1 Scope
- Run as a native Swift CLI client (no GUI app target).
- Detect Stadia controller input via `GameController`.
- Resolve active profile from frontmost app bundle ID (explicit mapped apps only).
- Support a small explicit `alwaysOn` control set for controls that should bypass frontmost-app matching.
- Execute mapped actions with debounce and edge-trigger defaults.

## Runtime Flow
1. Load `config/mappings.json`.
2. Subscribe to controller connect/disconnect notifications.
3. Bind button handlers for the extended gamepad profile.
   - Runtime currently polls button states at 20ms intervals for reliability on Stadia controller.
   - Runtime also samples configured analog axes (stick vertical scroll, right-stick pointer, and right-stick horizontal directional actions, profile-configurable) in the same polling loop.
4. On each button event:
   - Normalize event (`button`, `pressed`, `timestamp`, `repeat`).
   - Resolve the active app profile.
   - Resolve mapping from the active profile first, then from the explicit `alwaysOn` set.
   - If neither applies, skip action execution.
   - Apply safety checks (emergency toggle, profile enabled, debounce).
   - Execute action (`keystroke`, `holdKeystroke`, `shell`, `applescript`) or dry-run log.
5. On each configured analog sample:
   - Apply deadzone and direction/rate rules from `alwaysOn` config first, then from the active profile for features not overridden globally.
   - Translate analog motion into scroll, pointer move, or synthetic left/right action triggers.
   - Skip execution when neither `alwaysOn` nor the active profile provides that analog behavior.

## Safety Defaults
- Dry-run is enabled by default in config.
- Emergency toggle button can disable/enable all mapped actions during runtime.
- Keystroke injection requires Accessibility permission when live mode is enabled.
