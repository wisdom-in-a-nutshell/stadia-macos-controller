# Bridge installation and recovery

Use the shared machine wrapper on each Mac; do not copy built binaries between
machines. Local build/signing and Accessibility trust must match that machine.

```bash
~/GitHub/scripts/setup/stadia/install-launchd-stadia-controller-bridge.sh --mode dry-run
~/GitHub/scripts/setup/stadia/install-launchd-stadia-controller-bridge.sh --mode live
~/GitHub/scripts/setup/stadia/verify-launchd-stadia-controller-bridge.sh
~/GitHub/scripts/setup/stadia/uninstall-launchd-stadia-controller-bridge.sh
```

If the shared wrapper is unavailable, the corresponding `scripts/` commands
in this repo provide the project-local implementation.

## Stable identity and Accessibility

- Label and bundle/signing identifier: `com.stadia-controller-bridge`.
- App: `~/Library/Application Support/stadia-controller-bridge/StadiaControllerBridge.app`.
- Grant Accessibility to its `Contents/MacOS/stadia-controller-bridge` executable,
  not a temporary `.build/` binary.
- Installer signing defaults to `--sign-identity auto`: Apple certificate when
  available, otherwise ad-hoc. `adhoc` forces ad-hoc; an explicit certificate pins
  identity; `none` skips signing and is unsuitable for stable trust.

The installer reuses unchanged staged source to avoid unnecessary trust churn;
changed source or `--force-build` rebuilds it. Mapping-only changes hot-reload.
Runtime/action-schema or launchd changes require reinstalling before live proof.
Shell/AppleScript helper output is captured in bridge logs so failures remain
attributable to the action.

The installer also suppresses macOS Game Controller shortcuts that compete for
system/share buttons. Rerun it if a macOS update restores those shortcuts.

## Verify and recover

Use the verifier above, inspect the bounded bridge logs, and test a real button
against the changed behavior. A running process alone is not input proof.

```bash
tail -n 120 ~/Library/Logs/stadia-controller-bridge.launchd.out.log
tail -n 80 ~/Library/Logs/stadia-controller-bridge.launchd.err.log
```

- Events appear but actions do not: re-enable the staged executable in
  System Settings → Privacy & Security → Accessibility. Remove obsolete entries
  if necessary, then reinstall with the same signing identity.
- A reinstall breaks previously working actions: check signing/Accessibility
  identity before repeatedly rebuilding or re-signing.
- `home` never appears while `menu`, `options`, and `share` do: the controller
  mode/API may not expose Home. Map confirmed buttons rather than assuming
  permission failure. Search the bridge log for those button names.
- Apple Games/Game Center/Overlay/Launchpad opens: disable the connected
  controller's system shortcuts or let the installer reconcile them. Reconnect
  the controller; a logout/login may be needed for macOS to apply the change.

Local source runs and the read-only mapping preview are in [setup](setup.md).
