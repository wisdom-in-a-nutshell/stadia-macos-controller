#!/bin/zsh
set -euo pipefail

# Start Codex by default for each new Ghostty surface.
# If Codex exits, fall back to a normal interactive shell so the surface stays open.
if command -v codex >/dev/null 2>&1; then
  codex
fi

exec /bin/zsh -l
