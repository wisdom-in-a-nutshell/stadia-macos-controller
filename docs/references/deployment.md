# Deployment (Two Machines)

Use this when you want the controller bridge running on both machines with the same repo/config.

## 1) Clone and verify
On each machine:

```bash
git clone git@github.com:wisdom-in-a-nutshell/stadia-macos-controller.git ~/GitHub/stadia-macos-controller
cd ~/GitHub/stadia-macos-controller
swift build
```

## 2) Configure mappings
Edit `config/mappings.json` as needed. Hot reload is enabled while the bridge process is running.

## 3) Install launchd service
Install/update the LaunchAgent on each machine:

```bash
cd ~/GitHub/stadia-macos-controller
./scripts/install-launchd-stadia-controller-bridge.sh --mode live
```

For safer testing first:

```bash
./scripts/install-launchd-stadia-controller-bridge.sh --mode dry-run
```

## 4) Accessibility permission (first-time)
Grant Accessibility to the terminal process that launchd uses (or run once manually with prompt):

```bash
./scripts/run-bridge.sh --no-dry-run --prompt-accessibility
```

Then enable in:
- `System Settings > Privacy & Security > Accessibility`

## 5) Validate service state
```bash
launchctl print gui/$(id -u)/com.$USER.stadia-controller-bridge | sed -n '1,90p'
```

Check logs:
```bash
tail -n 80 ~/Library/Logs/stadia-controller-bridge.launchd.out.log
tail -n 80 ~/Library/Logs/stadia-controller-bridge.launchd.err.log
```

## 6) Update workflow
On either machine:

```bash
cd ~/GitHub/stadia-macos-controller
git pull --rebase
```

No restart is needed for mapping changes only (hot reload). Restart/reinstall is needed if code or launchd settings change.
