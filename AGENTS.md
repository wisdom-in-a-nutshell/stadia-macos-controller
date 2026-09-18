# Stadia macOS Controller

Local input bridge for a Stadia controller, Ghostty, Codex, and system shortcuts,
plus a read-only browser guide to the mappings.

- `config/mappings.json` owns mappings; `src/main.swift` owns the bridge.
  Exact button descriptions belong in the config, not a second table in docs.
- `~/GitHub/scripts/setup/stadia/` owns machine installation and launchd wiring;
  this repo owns bridge source and the project-local installer implementation.
- Local run/preview: `docs/references/setup.md`.
- Bridge installation, signing, Accessibility, and recovery:
  `docs/references/deployment.md`.
- Guide release and mapping constraints: `docs/references/repo-contract.md`.
- For Ghostty behavior, use `docs/architecture/ghostty-integration.md` and
  `docs/references/ghostty-mapping-rationale.md`.

## Validation

`./scripts/check-fast.sh` checks guide routes and mappings. Use
`./scripts/check-full.sh` for Swift/runtime changes; it includes the bridge build.
Guide-only deployment uses its own full gate without rebuilding the bridge.

Mappings hot-reload, but new runtime/schema behavior requires reinstalling the
staged app. Before claiming live behavior, verify the LaunchAgent and exercise
a real controller action. Guide health is not proof that the input bridge works.
