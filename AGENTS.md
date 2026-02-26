# Stadia macOS Controller Repo Guidance

## Goal
Build a local bridge that maps Stadia controller inputs to macOS actions and app-specific shortcuts (starting with Ghostty).

## Workflow
- Keep implementation pragmatic and testable on macOS.
- Prefer native Apple frameworks first when feasible.
- Keep mappings configurable (do not hardcode behavior in multiple places).
- Keep machine-level install/reconcile entrypoints in `~/GitHub/scripts/setup/` (project repo keeps bridge code/config as source of truth).
- Use explicit app profile mapping only; do not add global fallback profile behavior unless explicitly requested.

## Documentation
- Keep architecture notes in `docs/architecture/`.
- Keep stable lookup/config details in `docs/references/`.
- Track active work in `docs/projects/stadia-macos-controller/tasks.md`.

## Correctness Guardrails
- Do not claim bridge changes are correct without validation evidence (`launchctl print gui/$(id -u)/com.$USER.stadia-controller-bridge` plus a live button press check).
- Use canonical machine-level launchd entrypoints from `~/GitHub/scripts/setup/` to avoid setup drift across machines.
- Keep launchd service identity consistent (`com.<user>.stadia-controller-bridge`); do not introduce alternate labels unless explicitly requested.
