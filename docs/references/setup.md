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

## Accessibility Permission (required for keystroke actions)
1. Open `System Settings` > `Privacy & Security` > `Accessibility`.
2. Allow your terminal app (for example Ghostty/Terminal/iTerm) to control your Mac.
3. Restart the terminal session after enabling permission.

## Current Starter Mapping
- App profile: `com.mitchellh.ghostty` -> `ghostty`
- Button: `a`
- Action: `Cmd+D` (keyCode `2` with `command` modifier)

If your Ghostty split binding differs, edit `config/mappings.json`.
