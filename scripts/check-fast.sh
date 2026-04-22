#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

mapfile -t staged_files < <(git diff --cached --name-only --diff-filter=ACMR)

if [ "${#staged_files[@]}" -eq 0 ]; then
  echo "[check-fast] no staged files; skipping checks"
  exit 0
fi

echo "[check-fast] checking for merge conflict markers"
if command -v rg >/dev/null 2>&1; then
  if rg -n --no-messages "^(<<<<<<< |=======|>>>>>>> )" -- "${staged_files[@]}"; then
    echo "[check-fast] merge conflict markers detected"
    exit 1
  fi
else
  if grep -nE "^(<<<<<<< |=======|>>>>>>> )" "${staged_files[@]}"; then
    echo "[check-fast] merge conflict markers detected"
    exit 1
  fi
fi

git diff --cached --check

for file in "${staged_files[@]}"; do
  if [[ "$file" == *.sh ]] && [ -f "$file" ]; then
    bash -n "$file"
  fi
done

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
