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
2. Allow your terminal app (for example Ghostty/Terminal/iTerm) to control your Mac.
3. Restart the terminal session after enabling permission.

## Current Starter Mapping
- App profile: `com.mitchellh.ghostty` -> `ghostty`
- App profile: `com.openai.codex` -> `codex`
- Ghostty defaults:
  - `L2` (`leftTrigger`): `Cmd+D` split right
  - `R2` (`rightTrigger`): `Cmd+Shift+D` split down
  - `L1`/`R1`: previous/next tab
  - D-pad: split navigation (Cmd+Opt+Arrow)
- Codex defaults:
  - `A`: `holdKeystroke` Space (keyCode `49`)
  - `B`: Enter (keyCode `36`)
  - `L1`/`R1`: previous/next tab

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
