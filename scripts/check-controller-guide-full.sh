#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_FAST_CHECK="${REPO_FAST_CHECK:-$HOME/GitHub/scripts/bin/repo-fast-check}"

cd "${ROOT_DIR}"

"${REPO_FAST_CHECK}" \
  --repo-root "${ROOT_DIR}" \
  --scope tracked \
  --require-path AGENTS.md \
  --require-path docs/architecture \
  --require-path docs/references \
  --require-path docs/projects \
  --require-path tmp \
  --check-shell \
  --check-python \
  --check-json \
  --no-input

python3 scripts/check-controller-guide.py
python3 scripts/check-mappings.py

echo "[check-controller-guide-full] checks passed"
