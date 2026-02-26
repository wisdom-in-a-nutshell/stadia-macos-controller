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

## Current Starter Mapping
- App profile: `com.mitchellh.ghostty` -> `ghostty`
- Ghostty defaults:
  - `R2` (`rightTrigger`): hold Space (`holdKeystroke`)
  - `Options`: close focused split surface (`Cmd+W`)
  - `Menu`: open `/model`
  - `X`: toggle split zoom (maximize/restore focused split)
  - `L1` (`leftShoulder`): cycle tabs (next tab)
  - `R1` (`rightShoulder`): cycle split focus in current tab
  - D-pad `Up/Down`: model picker up/down
  - D-pad `Left/Right`: currently unassigned (reserved for future)

Non-profiled apps:
- If frontmost app is not mapped in `appProfiles`, bridge logs `[SKIP] no active app profile` and executes nothing.

If your Ghostty split binding differs, edit `config/mappings.json`.
For design intent behind the current layout, see `docs/references/ghostty-mapping-rationale.md`.

## Hot Reload
- `config/mappings.json` is watched while the bridge is running.
- Save changes to mappings and the process reloads automatically.
- Code changes still require a process restart.

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
- Symptom: worked earlier, then broke right after reinstall.
  - Cause: signing identity changed, or app executable was unnecessarily rebuilt/re-signed.
  - Fix: reinstall with stable signing:
    - `cd ~/GitHub/scripts && ./setup/stadia/install-launchd-stadia-controller-bridge.sh --mode live`
- Fast status checks:
  - `launchctl print gui/$(id -u)/com.stadia-controller-bridge | sed -n '1,90p'`
  - `tail -n 120 ~/Library/Logs/stadia-controller-bridge.launchd.out.log`
