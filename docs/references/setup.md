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
2. Allow this staged bridge binary:
   - `~/Library/Application Support/stadia-controller-bridge/bin/stadia-controller-bridge`
3. Keep using a stable signing mode (`--sign-identity adhoc`) to avoid trust churn.

## Current Starter Mapping
- App profile: `com.mitchellh.ghostty` -> `ghostty`
- Ghostty defaults:
  - `R2` (`rightTrigger`): hold Space (`holdKeystroke`)
  - `L1`/`R1`: previous/next tab
  - D-pad: split navigation (Cmd+Opt+Arrow)

Non-profiled apps:
- If frontmost app is not mapped in `appProfiles`, bridge logs `[SKIP] no active app profile` and executes nothing.

If your Ghostty split binding differs, edit `config/mappings.json`.

## Hot Reload
- `config/mappings.json` is watched while the bridge is running.
- Save changes to mappings and the process reloads automatically.
- Code changes still require a process restart.

## Launchd Service (optional)
Install as a user LaunchAgent:

```bash
cd ~/GitHub/scripts
./setup/install-launchd-stadia-controller-bridge.sh --mode live --sign-identity adhoc
```

Uninstall:

```bash
cd ~/GitHub/scripts
./setup/uninstall-launchd-stadia-controller-bridge.sh
```

## Troubleshooting (Recurring Issues)
- Symptom: controller events appear in logs but no actions fire.
  - Cause: Accessibility trust missing for staged binary.
  - Fix: re-enable `~/Library/Application Support/stadia-controller-bridge/bin/stadia-controller-bridge` in Accessibility.
- Symptom: worked earlier, then broke right after reinstall.
  - Cause: signing identity changed, so macOS trust entry no longer matches.
  - Fix: reinstall with stable signing:
    - `cd ~/GitHub/scripts && ./setup/install-launchd-stadia-controller-bridge.sh --mode live --sign-identity adhoc`
- Fast status checks:
  - `launchctl print gui/$(id -u)/com.$USER.stadia-controller-bridge | sed -n '1,90p'`
  - `tail -n 120 ~/Library/Logs/stadia-controller-bridge.launchd.out.log`
