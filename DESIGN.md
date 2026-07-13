# Controller Guide Design System

## Register

Product interface with a quiet editorial edge. The guide should feel like a
carefully printed console control sheet translated into a native-feeling macOS
tool: direct, calm, and easy to scan.

## Visual direction

- Controller-dominant master-detail composition.
- Cool sage-tinted off-white canvas; never cream, beige, or paper-textured.
- Flat surfaces separated by hairlines. No decorative shadows or glass effects.
- Sage indicates selection, focus, and active state.
- Amber is reserved for situational guidance.
- Earthy rose is reserved for errors that require attention.

## Color tokens

Use these tokens rather than literal colors in component rules.

| Token | Light value | Purpose |
| --- | --- | --- |
| `--bg` | `oklch(0.977 0.004 150)` | Application canvas |
| `--surface` | `oklch(0.993 0.003 150)` | Primary surface |
| `--surface-soft` | `oklch(0.958 0.006 150)` | Secondary grouping |
| `--text` | `oklch(0.27 0.014 152)` | Primary text |
| `--muted` | `oklch(0.47 0.013 152)` | Supporting text |
| `--line` | `oklch(0.9 0.006 152)` | Structural hairline |
| `--accent` | `oklch(0.57 0.068 150)` | Active state and focus |
| `--accent-soft` | `oklch(0.935 0.026 150)` | Selected background |
| `--amber` | `oklch(0.75 0.108 83)` | Caution marker |
| `--amber-soft` | `oklch(0.935 0.05 84)` | Caution background |
| `--rose` | `oklch(0.6 0.12 35)` | Error marker |
| `--rose-soft` | `oklch(0.945 0.035 40)` | Error background |

Dark mode uses the corresponding Adi Design charcoal, surface, text, and accent
overrides in `guide/styles.css`.

## Typography

- Newsreader for the page title and selected-action heading.
- Inter for interface chrome, controls, descriptions, and metadata.
- System monospace for action types, commands, key codes, and config paths.
- Local-first stacks only; the guide must not contact a font CDN.

Fixed product type ramp:

| Token | Size | Role |
| --- | --- | --- |
| `--font-micro` | `0.75rem` | Compact metadata |
| `--font-small` | `0.875rem` | Secondary UI |
| `--font-body` | `1rem` | Body and controls |
| `--font-lead` | `1.25rem` | Section emphasis |
| `--font-detail` | `1.625rem` | Selected-action heading |
| `--font-title` | `2rem` | Page title |

Body line height is `1.55`; editorial headings use `1.15` to `1.2`.

## Spacing and shape

- Spacing scale: 4, 8, 12, 18, 28, and 44 pixels.
- Control radius: 8px.
- Panel radius: 14px.
- Large controller stage radius: 18px.
- Minimum interactive target: 44 by 44 pixels.
- Page width is capped so the guide does not stretch across very wide displays.

## Motion

- State changes only, using 150ms or 220ms ease-out transitions.
- Selection may shift color or position by at most two pixels.
- No entrance choreography, bounce, ambient motion, or animated decoration.
- Remove nonessential motion under `prefers-reduced-motion`.

## Responsive behavior

- Narrow screens stack controller, details, and mapping index in one column.
- Wide screens use a controller-first main column and a sticky detail rail.
- Profile controls can scroll horizontally but remain keyboard accessible.
- The diagram scales from its SVG view box; no mapped control disappears.
- Touch and keyboard interaction never depend on hover.

## Anti-patterns

- Generic dashboard metric cards.
- Dense grids of identical rounded cards.
- Neon gaming HUD styling.
- Warm cream or faux-paper surfaces.
- A second hand-maintained list of controller actions.
- Technical implementation details as the primary label.
