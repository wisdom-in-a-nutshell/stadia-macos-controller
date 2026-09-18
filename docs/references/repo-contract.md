# Mapping and guide release contracts

## Input boundary

`config/mappings.json` is the source of truth. Use explicit `appProfiles`;
`alwaysOn` is a cross-app list, not a fallback profile. Unmapped frontmost apps
receive only `alwaysOn` actions. Keep latency-sensitive Codex controls on direct
keystrokes; `scripts/check-mappings.py` enforces this boundary.

`src/main.swift` owns execution and hot reload. Machine installation, signing,
Accessibility, and physical controller proof are in [deployment](deployment.md).

## Guide release

The guide is read-only. Its server allowlists assets and `/api/mappings` rather
than exposing the checkout. `scripts/check-controller-guide-full.sh` validates
the guide, source isolation, mapping parity, client output, and release contract.
The repository full gate additionally builds the independent Swift bridge.

`scripts/deploy-controller-guide.sh` is the JSON-default production client.
Default invocation is a dry run. Operators use `--apply`, `--status`, `--logs`,
`--rollback`, or `--uninstall` through that client; rollback changes live state.
Use `--plain` for readable output and `--no-input` for unattended operation.

The client accepts clean committed `main`, gates a detached exact-SHA worktree,
and rechecks source stability before activation. Read-only releases contain
only guide assets, mappings, the standard-library server, and source identity,
under `~/.local/share/stadia-controller-guide/production/releases/`.
`current`/`previous` pointers support activation and recovery; failed launch or
health restores the previous release. Health checks the served source SHA so a
responsive stale process cannot pass.

Production listens on `127.0.0.1:8798`; the shared tunnel and Cloudflare Access
provide `https://controller.adithyan.io/`. The launchd environment is allowlisted.
Use the client's normalized status and bounded redacted logs; raw `launchctl
print` can expose inherited environment. Health timeout is 30 seconds by default
(`--timeout 1..600`); `--progress off` leaves only final JSON on stdout.
