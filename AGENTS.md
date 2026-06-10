# Stadia macOS Controller

Local macOS input bridge for using a Stadia controller with Ghostty, Codex, and system-level shortcuts.

## Scope

This root `AGENTS.md` applies repo-wide. Keep exact operational detail in `docs/` instead of adding nested agent guidance.

## Start Here

- `docs/architecture/bridge-overview.md`: runtime shape, boundaries, and event flow.
- `docs/architecture/ghostty-integration.md`: Ghostty-specific action flow.
- `docs/references/repo-contract.md`: repo map, validation, runtime, install, and mapping contracts.
- `docs/references/setup.md`: local run, accessibility, launchd, and troubleshooting commands.

## Docs Contract

- `docs/architecture/`: subsystem shape, boundaries, responsibilities, and main flows.
- `docs/references/`: commands, file maps, config contracts, and operational lookup facts.
- `docs/projects/<project>/tasks.md`: active multi-session execution state.
- `docs/projects/archive/`: completed or superseded trackers.

## Repo Rules

- Keep `config/mappings.json` as the source of truth for controller mappings.
- Keep machine-level install and launchd wiring in `~/GitHub/scripts/setup/stadia/`; this repo owns bridge code, config, and fallback project-local scripts.
- Runtime or config-schema changes require reinstalling the staged launchd app before claiming live behavior is updated.
- Update docs in the same change when bridge behavior, config contracts, launchd behavior, or operational commands change.

## Validation

- Run `./scripts/check-fast.sh` before handoff.
- Run `./scripts/check-full.sh` for runtime, launchd, or Swift code changes where a full build matters.
- For live launchd changes, verify the LaunchAgent and test a real controller action against the changed behavior.
