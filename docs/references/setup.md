# Local Setup (Phase 1)

## Prerequisites
- macOS with Xcode CLI tools installed.
- Stadia controller connected (USB or wireless).

## Run in Dry-Run Mode (default)
```bash
swift run stadia-controller-bridge --config config/mappings.json
```

or:

```bash
./scripts/run-bridge.sh
```

## Run in Live Mode
```bash
swift run stadia-controller-bridge --config config/mappings.json --no-dry-run
```

If Accessibility permission has not appeared yet, run once with prompt enabled:

```bash
swift run stadia-controller-bridge --config config/mappings.json --no-dry-run --prompt-accessibility
```

## Accessibility Permission (required for keystroke actions)
1. Open `System Settings` > `Privacy & Security` > `Accessibility`.
2. Allow this staged app executable:
   - `~/Library/Application Support/stadia-controller-bridge/StadiaControllerBridge.app/Contents/MacOS/stadia-controller-bridge`
3. Keep one stable install identity (`--sign-identity auto` default, with fallback to ad-hoc).

## Stable Names (Both Machines)
- LaunchAgent label default: `com.stadia-controller-bridge`
- Bundle identifier/signing identifier default: `com.stadia-controller-bridge`
- Staged app bundle path: `~/Library/Application Support/stadia-controller-bridge/StadiaControllerBridge.app`

## Signing Modes (Installer)
- `--sign-identity auto` (default): prefer Apple cert if available, fallback to ad-hoc.
- `--sign-identity adhoc`: always ad-hoc sign (`-`), no Apple cert dependency.
- `--sign-identity "Apple Development: ..."`: pin one explicit cert for maximum consistency.
- `--sign-identity none`: skip signing (not recommended).

## Current Mapping
`config/mappings.json` is the source of truth for the live controller layout, including keycodes, modifiers, Ghostty actions, helper commands, debounce settings, and descriptions.

Operational notes:
- `alwaysOn` controls remain active outside Ghostty.
- Ghostty profile controls only fire when `com.mitchellh.ghostty` is frontmost.
- Codex app profile controls only fire when `com.openai.codex` is frontmost.
- Left-stick vertical scroll is configured in `alwaysOn`; when Ghostty is frontmost, the bridge targets Ghostty's focused terminal directly so scrolling follows tab/split focus instead of mouse cursor position.
- In Codex app, the profile keeps high-frequency text-entry, chat switching, and terminal-toggle controls available without enabling Ghostty-only tab, split, or surface-management actions.
- D-pad arrow-key controls are always-on where no active app profile overrides them; Ghostty overrides horizontal D-pad with zoom actions, and Codex app overrides horizontal D-pad with left/right panel toggles.
- Keep exact button-to-action documentation in `config/mappings.json`, not in this setup guide.

Dictation stability note:
- Auto-submit-on-release behavior is intentionally not configured for triggers.
- Reason: dictation completion timing is asynchronous, so automatic `Enter` can submit partial/previous text.
- Recommended pattern: keep trigger and submit separate (for example, trigger on `R2`, submit with a dedicated button).

Non-profiled apps:
- If frontmost app is not mapped in `appProfiles`, only controls listed in `alwaysOn` still execute.
- All other controls log `[SKIP] no active app profile`.

If your Ghostty split binding differs, edit `config/mappings.json`.
For design intent behind the current layout, see `docs/references/ghostty-mapping-rationale.md`.
If Ghostty AppleScript is disabled or you are on Ghostty older than `1.3.0`, mappings that depend on Ghostty AppleScript helpers must be changed back to plain keystrokes, `ghosttyAction`, or another supported action type.

## Hot Reload
- `config/mappings.json` is watched while the bridge is running.
- Save changes to mappings and the process reloads automatically.
- Code changes still require a process restart.
- Runtime/config-schema changes also require reinstalling the staged launchd app so launchd stops running the old binary:
  - `~/GitHub/scripts/setup/stadia/install-launchd-stadia-controller-bridge.sh --mode live`

## Ghostty AppleScript Note
- This repo intentionally builds part of the Ghostty flow on top of Ghostty's native AppleScript support.
- Current AppleScript usage is intentionally narrow:
  - shell helpers create Codex/Ghostty surfaces with custom startup behavior.
  - `ghosttyAction` dispatches Ghostty-native terminal actions through Ghostty's AppleScript bridge.
- Ghostty marks AppleScript as a preview API in `1.3.x`, but this is currently the cleanest way to express tab-level startup behavior and has been validated in live use.

## Launchd Service (optional)
Install as a user LaunchAgent:

```bash
cd ~/GitHub/scripts
./setup/stadia/install-launchd-stadia-controller-bridge.sh --mode live
```

Uninstall:

```bash
cd ~/GitHub/scripts
./setup/stadia/uninstall-launchd-stadia-controller-bridge.sh
```

Verify:

```bash
cd ~/GitHub/scripts
./setup/stadia/verify-launchd-stadia-controller-bridge.sh
```

## Troubleshooting (Recurring Issues)
- Symptom: controller events appear in logs but no actions fire.
  - Cause: Accessibility trust missing for staged app executable.
  - Fix: re-enable `~/Library/Application Support/stadia-controller-bridge/StadiaControllerBridge.app/Contents/MacOS/stadia-controller-bridge` in Accessibility.
- Symptom: `menu`/`options`/`share` events appear, but `home` never appears in logs even after repeated presses.
  - Cause: likely input exposure limitation for current controller mode/connection; some APIs do not surface Assistant/Home on Stadia.
  - Fix: treat `home` as unavailable on that setup; map other confirmed buttons instead.
  - Quick check:
    - `rg -n "button=home|button=share|button=menu|button=options" ~/Library/Logs/stadia-controller-bridge.launchd.out.log -S`
- Symptom: worked earlier, then broke right after reinstall.
  - Cause: signing identity changed, or app executable was unnecessarily rebuilt/re-signed.
  - Fix: reinstall with stable signing:
    - `cd ~/GitHub/scripts && ./setup/stadia/install-launchd-stadia-controller-bridge.sh --mode live`
- Fast status checks:
  - `launchctl print gui/$(id -u)/com.stadia-controller-bridge | sed -n '1,90p'`
  - `tail -n 120 ~/Library/Logs/stadia-controller-bridge.launchd.out.log`

External context:
- Google Chrome team notes Stadia Assistant/Capture are outside the standard gamepad set and need lower-level access (`WebHID`) in browsers: https://developer.chrome.com/blog/stadia
