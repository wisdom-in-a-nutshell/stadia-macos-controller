#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_FAST_CHECK="${REPO_FAST_CHECK:-$HOME/GitHub/scripts/bin/repo-fast-check}"

cd "$ROOT_DIR"

"$REPO_FAST_CHECK" \
  --repo-root "$ROOT_DIR" \
  --scope staged \
  --require-path AGENTS.md \
  --require-path docs/architecture \
  --require-path docs/references \
  --require-path docs/projects \
  --require-path tmp \
  --check-shell \
  --no-input

mapfile -t staged_files < <(git diff --cached --name-only --diff-filter=ACMR)

needs_swift_manifest_check=0
for file in "${staged_files[@]}"; do
  case "$file" in
    Package.swift|Package.resolved)
      needs_swift_manifest_check=1
      ;;
  esac
done

if [ "$needs_swift_manifest_check" -eq 1 ]; then
  echo "[check-fast] validating Swift package manifest"
  swift package dump-package >/dev/null
else
  echo "[check-fast] no staged Swift manifest files; skipping Swift manifest check"
fi

echo "[check-fast] checks passed"
