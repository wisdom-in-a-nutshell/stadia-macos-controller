#!/usr/bin/env bash
set -euo pipefail

swift run stadia-controller-bridge --config config/mappings.json "$@"
