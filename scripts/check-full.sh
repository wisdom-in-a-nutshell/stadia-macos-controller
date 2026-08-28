#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "[check-full] validating controller guide and mappings"
scripts/check-controller-guide-full.sh

echo "[check-full] validating Swift package manifest"
swift package dump-package >/dev/null

echo "[check-full] building Swift package"
swift build

echo "[check-full] checks passed"
