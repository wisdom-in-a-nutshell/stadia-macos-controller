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
Canonical machine-ops command (recommended) from `~/GitHub/scripts`:

```bash
cd ~/GitHub/scripts
./setup/install-launchd-stadia-controller-bridge.sh --mode live --sign-identity auto
```

Project-local fallback (equivalent):

```bash
cd ~/GitHub/stadia-macos-controller
./scripts/install-launchd-stadia-controller-bridge.sh --mode live
```

For safer testing first:

```bash
cd ~/GitHub/scripts
./setup/install-launchd-stadia-controller-bridge.sh --mode dry-run
```

What this installer now does:
- Builds a fresh binary (`release` by default).
- Stages it to a stable runtime path: `~/Library/Application Support/stadia-controller-bridge/bin/stadia-controller-bridge`.
- Code-signs the staged binary (auto identity by default).
- Points launchd to that staged path.

This avoids relying on transient `.build/...` binaries and reduces repeated Accessibility re-approval.

## 4) Accessibility permission (first-time, one stable binary)
Grant Accessibility to the staged binary path used by launchd:
- `System Settings > Privacy & Security > Accessibility`
- Add/enable:
  - `~/Library/Application Support/stadia-controller-bridge/bin/stadia-controller-bridge`

If entries got messy from old runs:
1. Remove old `stadia-controller-bridge` entries.
2. Re-add the staged binary path above.
3. Re-run installer:

```bash
cd ~/GitHub/scripts
./setup/install-launchd-stadia-controller-bridge.sh --mode live --sign-identity auto
```

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
