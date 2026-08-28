#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPLOY="${ROOT_DIR}/scripts/deploy-controller-guide.sh"
ACTION="dry-run"
APPLY=0
LOG_LINES=""

printf 'DEPRECATED: use scripts/deploy-controller-guide.sh; forwarding safely\n' >&2

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)
      APPLY=1
      shift
      ;;
    --dry-run|--no-input)
      shift
      ;;
    --status)
      ACTION="status"
      shift
      ;;
    --logs)
      ACTION="logs"
      if [[ -n "${2:-}" && "${2:-}" != --* ]]; then
        LOG_LINES="$2"
        shift 2
      else
        shift
      fi
      ;;
    --uninstall)
      ACTION="uninstall"
      shift
      ;;
    -h|--help)
      exec "${DEPLOY}" --help
      ;;
    --label|--port|--python)
      printf 'ERROR: %s override is retired; production identity is fixed\n' "$1" >&2
      exit 2
      ;;
    *)
      printf 'ERROR: unknown option: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

case "${ACTION}" in
  status)
    exec "${DEPLOY}" --status --plain --no-input
    ;;
  logs)
    if [[ -n "${LOG_LINES}" ]]; then
      exec "${DEPLOY}" --logs "${LOG_LINES}" --plain --no-input
    fi
    exec "${DEPLOY}" --logs --plain --no-input
    ;;
  uninstall)
    if [[ "${APPLY}" -eq 1 ]]; then
      exec "${DEPLOY}" --uninstall --plain --no-input
    fi
    exec "${DEPLOY}" --dry-run --plain --no-input
    ;;
  dry-run)
    if [[ "${APPLY}" -eq 1 ]]; then
      exec "${DEPLOY}" --apply --plain --no-input
    fi
    exec "${DEPLOY}" --dry-run --plain --no-input
    ;;
esac
