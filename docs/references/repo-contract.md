# Repo Contract

Use this page for repo-level commands, file map notes, and runtime contracts.

## Repo Map
- `AGENTS.md`: cold-start repo router for agents.
- `src/main.swift`: CLI parsing, config loading and validation, frontmost-app profile resolution, action execution, controller polling, and config hot reload.
- `config/mappings.json`: source of truth for app profiles, `alwaysOn` controls, per-profile mappings, and safety defaults.
- `guide/`: dependency-free, read-only controller map rendered from the live mapping config.
- `scripts/run-controller-guide.sh`: start the loopback guide server and open it in the default browser.
- `scripts/serve-controller-guide.py`: allowlisted static/API server for the guide; never serves the repo root.
- `scripts/check-controller-guide.py`: loopback route, config parity, isolation, and JavaScript validation.
- `scripts/check-controller-guide-full.sh`: tracked shell/Python/JSON checks plus the complete guide
  and mapping contract suite; this is the controller-guide production release gate.
- `scripts/check-mappings.py`: fast action-schema checks and a guard against label-bound menu AppleScripts.
- `scripts/deploy-controller-guide.sh`: non-interactive, structured deploy contract
  used by the Mac mini production reconciler; JSON-default dry run, exact-source full gate,
  versioned activation, health, status, sanitized logs, rollback, and uninstall share this surface.
- `scripts/deploy_controller_guide.py`: testable implementation behind the stable shell entrypoint.
- `scripts/install-launchd-controller-guide.sh`: deprecated compatibility forwarder. It preserves
  common older invocations without rendering a plist or printing raw launchd state; new automation
  must use the deploy client directly.
- `scripts/run-bridge.sh`: local `swift run` wrapper.
- `scripts/check-fast.sh`: fast repo validation. Delegates cheap generic checks to `~/GitHub/scripts/bin/repo-fast-check`, validates the controller guide and mappings, then validates Swift package manifest parsing when Swift manifest files are staged.
- `scripts/install-launchd-stadia-controller-bridge.sh`: project-local fallback installer for the bridge LaunchAgent.
- `scripts/verify-launchd-stadia-controller-bridge.sh`: project-local fallback verifier for launchd wiring, staged runtime path, and signing identifier.
- `scripts/uninstall-launchd-stadia-controller-bridge.sh`: project-local fallback cleanup for bridge LaunchAgents.
- `docs/architecture/`: subsystem shape, boundaries, and runtime flow.
- `docs/references/`: durable commands, config contracts, and operational lookup notes.
- `docs/projects/`: active multi-session execution state when needed.
- `tmp/`: repo-local scratch space for disposable agent artifacts.

## Validation
- Run `./scripts/check-fast.sh` for repo-native fast validation on every change.
- Controller Guide checks run as part of `./scripts/check-fast.sh` and can also be run directly with `python3 scripts/check-controller-guide.py`.
- Mapping checks run as part of `./scripts/check-fast.sh` and can also be run directly with `python3 scripts/check-mappings.py`.
- Validate the guide deploy interface with its default JSON dry run and inspect production with
  `scripts/deploy-controller-guide.sh --status --json --no-input`.
- `./scripts/check-full.sh` runs the controller-guide full gate before the Swift manifest/build.
  Production guide delivery invokes the service-scoped full gate directly so a static guide release
  does not rebuild the unrelated Accessibility bridge.
- Run `swift build` when `Package.swift`, `src/`, or runtime-facing scripts change.
- Do not claim launchd or runtime changes are healthy without both:
  - `launchctl print gui/$(id -u)/com.stadia-controller-bridge`
  - a live controller button press check against the changed behavior
- After install or reinstall work, prefer `~/GitHub/scripts/setup/stadia/verify-launchd-stadia-controller-bridge.sh`.
- If the shared machine-level wrapper is unavailable, use `./scripts/verify-launchd-stadia-controller-bridge.sh`.

## Runtime And Install Contracts
- This repo owns bridge code and `config/mappings.json`.
- Canonical machine-level install and reconcile entrypoints live in `~/GitHub/scripts/setup/stadia/`.
- Keep the launchd label stable as `com.stadia-controller-bridge`.
- Keep the staged runtime target stable as `~/Library/Application Support/stadia-controller-bridge/StadiaControllerBridge.app`.
- Keep the signing or bundle identifier stable as `com.stadia-controller-bridge`.
- Do not introduce per-machine launchd labels or staged runtime paths unless explicitly requested.
- `config/mappings.json` hot-reloads while the bridge process is running.
- Changes that add a new runtime action type, CLI behavior, or config schema require reinstalling the staged launchd app so launchd stops running the old binary.
- Shell and AppleScript helper stdout/stderr are captured by the bridge; failed helper actions should surface captured output in the bridge log instead of leaking raw subprocess lines to launchd stderr.

## Controller Guide Release Contract

- The production client accepts only clean committed `main`, creates a detached worktree at the
  captured SHA, runs `scripts/check-controller-guide-full.sh` there, and rechecks the live checkout
  before activation.
- A release contains only `guide/`, `config/mappings.json`, the standard-library server, and its
  source marker. It is made read-only under
  `~/.local/share/stadia-controller-guide/production/releases/`.
- `current` and `previous` symlinks provide atomic activation and explicit rollback. A failed
  launchd load or local health proof restores both prior pointers automatically. Health includes the
  served source SHA, so a responsive stale process cannot satisfy exact-revision activation.
- The launchd job runs through `/usr/bin/env -i` with an allowlisted environment. Status never
  prints raw launchd state; log output is bounded and redacts query strings and credential-shaped
  values.

## Mapping Contract
- Use explicit `appProfiles` matching only.
- `alwaysOn` is an explicit cross-app control list, not a fallback profile.
- If the frontmost bundle ID is unmapped, only `alwaysOn` controls should fire.
- Keep latency-sensitive Codex controls on direct keystroke actions; `scripts/check-mappings.py` enforces this contract.
