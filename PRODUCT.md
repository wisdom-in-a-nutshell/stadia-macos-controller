# Controller Guide

## Product

A private, local web guide for the Stadia macOS Controller bridge. It lets one
operator see what every controller input does in the active application without
having to remember shortcuts or inspect JSON.

## Platform and audience

- Local web interface on macOS.
- Designed for the repository owner while using Codex, Ghostty, and other mapped
  applications with a Stadia controller.
- No accounts, analytics, network services, or public deployment.

## Core promise

The controller explains itself from the same mapping configuration that drives
the bridge.

## Product principles

1. **One source of truth.** Read `config/mappings.json`; never maintain a second
   hand-authored mapping catalogue in the interface.
2. **Controller first.** The physical controller is the primary navigation and
   comprehension model, not an administrative table.
3. **Context is visible.** Make the selected application profile and any focus-
   dependent behavior immediately clear.
4. **Details on demand.** Show a concise action label at a glance and reveal the
   underlying action, modifiers, and operational notes when selected.
5. **Local and dependable.** Keep startup simple, dependencies small, and failure
   states explicit.

## Experience direction

- Calm console controls guide rather than a dashboard or gaming HUD.
- Controller-dominant master-detail composition: profile selection above,
  controller map center-left, selected-action detail rail on the right.
- Adi Design visual language: cool off-white surfaces, sage interaction states,
  amber cautions, Newsreader for editorial headings, Inter for interface text.
- Flat hairline surfaces and restrained state-only motion.

## Accessibility and adaptation

- Keyboard-accessible controls with visible focus states.
- WCAG AA contrast for functional text and controls.
- Useful at desktop and narrow viewport widths without hiding mapping content.
- Honor reduced-motion preferences.

## Explicit non-goals

- Editing or writing controller mappings.
- Replacing `config/mappings.json` as configuration authority.
- Simulating controller input.
- Remote access, multi-user collaboration, or telemetry.
- Decorative skeuomorphism, neon game styling, or dense card-grid dashboards.

## Success criteria

- The operator can identify any mapped control and its action within a few
  seconds.
- Switching application profiles updates the diagram from live configuration.
- The Codex browser-focus limitation is visible wherever it affects task
  switching.
- Configuration and loading errors are understandable and actionable.
