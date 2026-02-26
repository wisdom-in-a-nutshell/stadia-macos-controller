# Stadia macOS Controller Repo Guidance

## Goal
Build a local bridge that maps Stadia controller inputs to macOS actions and app-specific shortcuts (starting with Ghostty).

## Workflow
- Keep implementation pragmatic and testable on macOS.
- Prefer native Apple frameworks first when feasible.
- Keep mappings configurable (do not hardcode behavior in multiple places).

## Documentation
- Keep architecture notes in `docs/architecture/`.
- Keep stable lookup/config details in `docs/references/`.
- Track active work in `docs/projects/stadia-macos-controller/tasks.md`.
