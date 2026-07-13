#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="dry-run"
FORMAT="json"
REQUEST_ID="$(uuidgen 2>/dev/null | tr '[:upper:]' '[:lower:]' || printf 'local')"
START_SECONDS="$SECONDS"
LOCAL_URL="http://127.0.0.1:8798/api/health"
PUBLIC_URL="https://controller.adithyan.io/"
LABEL="com.${USER}.stadia-controller-guide"

usage() {
  cat <<'USAGE'
Usage: deploy-controller-guide.sh [options]

Check and deploy the controller guide local production service.

Options:
  --apply       Run checks, refresh launchd, and smoke the local service
  --dry-run     Describe the planned deployment without changing state (default)
  --json        Emit one JSON result object on stdout (default)
  --plain       Emit a compact, stable text result on stdout
  --no-input    Assert non-interactive operation (accepted for automation)
  -h, --help    Show this help

Exit codes:
  0  Success
  1  Validation or install failure
  2  Invalid usage
  5  Local service health check failed
USAGE
}

emit_result() {
  local status="$1"
  local mode="$2"
  local error_code="${3:-}"
  local error_message="${4:-}"
  local duration_ms="$(( (SECONDS - START_SECONDS) * 1000 ))"

  if [[ "$FORMAT" == "plain" ]]; then
    if [[ "$status" == "ok" ]]; then
      printf 'status=ok mode=%s service=stadia-controller-guide local_url=%s public_url=%s label=%s\n' \
        "$mode" "$LOCAL_URL" "$PUBLIC_URL" "$LABEL"
    else
      printf 'status=error mode=%s code=%s message=%s\n' "$mode" "$error_code" "$error_message"
    fi
    return
  fi

  python3 - "$status" "$mode" "$error_code" "$error_message" "$duration_ms" \
    "$REQUEST_ID" "$LOCAL_URL" "$PUBLIC_URL" "$LABEL" <<'PY'
import datetime
import json
import sys

status, mode, error_code, error_message, duration_ms, request_id, local_url, public_url, label = sys.argv[1:]
payload = {
    "schema_version": "1.0",
    "command": "deploy-controller-guide",
    "status": status,
    "data": {
        "mode": mode,
        "service": "stadia-controller-guide",
        "local_url": local_url,
        "public_url": public_url,
        "launchd_label": label,
    },
    "error": None if status == "ok" else {
        "code": error_code,
        "message": error_message,
        "retryable": error_code in {"E_INSTALL_FAILED", "E_HEALTH_TIMEOUT"},
    },
    "meta": {
        "request_id": request_id,
        "duration_ms": int(duration_ms),
        "timestamp_utc": datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00", "Z"),
    },
}
print(json.dumps(payload, separators=(",", ":")))
PY
}

fail_usage() {
  local message="$1"
  printf 'ERROR: %s\n' "$message" >&2
  emit_result "error" "$MODE" "E_INVALID_USAGE" "$message"
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)
      MODE="apply"
      shift
      ;;
    --dry-run)
      MODE="dry-run"
      shift
      ;;
    --json)
      FORMAT="json"
      shift
      ;;
    --plain)
      FORMAT="plain"
      shift
      ;;
    --no-input)
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail_usage "unknown option: $1"
      ;;
  esac
done

if [[ "$MODE" == "dry-run" ]]; then
  printf '[deploy-controller-guide] dry-run: would validate, install launchd, and smoke %s\n' "$LOCAL_URL" >&2
  emit_result "ok" "dry-run"
  exit 0
fi

printf '[deploy-controller-guide] running repository checks\n' >&2
if ! "$ROOT_DIR/scripts/check-fast.sh" >&2; then
  emit_result "error" "apply" "E_CHECK_FAILED" "repository checks failed"
  exit 1
fi

printf '[deploy-controller-guide] refreshing LaunchAgent\n' >&2
if ! "$ROOT_DIR/scripts/install-launchd-controller-guide.sh" --apply --no-input >&2; then
  emit_result "error" "apply" "E_INSTALL_FAILED" "LaunchAgent install failed"
  exit 1
fi

printf '[deploy-controller-guide] checking local service\n' >&2
if ! curl --fail --silent --show-error --max-time 5 "$LOCAL_URL" >/dev/null; then
  emit_result "error" "apply" "E_HEALTH_TIMEOUT" "local health check failed"
  exit 5
fi

emit_result "ok" "apply"
