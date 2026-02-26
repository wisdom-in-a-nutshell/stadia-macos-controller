# Bridge Overview

## Phase 1 Scope
- Run as a native Swift CLI client (no GUI app target).
- Detect Stadia controller input via `GameController`.
- Resolve active profile from frontmost app bundle ID (`ghostty` + `default`).
- Execute mapped actions with debounce and edge-trigger defaults.

## Runtime Flow
1. Load `config/mappings.json`.
2. Subscribe to controller connect/disconnect notifications.
3. Bind button handlers for the extended gamepad profile.
4. On each button event:
   - Normalize event (`button`, `pressed`, `timestamp`, `repeat`).
   - Resolve active app profile.
   - Resolve mapping from active profile, then fallback to `default`.
   - Apply safety checks (emergency toggle, profile enabled, debounce).
   - Execute action (`keystroke`, `shell`, `applescript`) or dry-run log.

## Safety Defaults
- Dry-run is enabled by default in config.
- Emergency toggle button can disable/enable all mapped actions during runtime.
- Keystroke injection requires Accessibility permission when live mode is enabled.
