#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LABEL="com.${USER}.stadia-controller-guide"
PORT=8798
PYTHON_BIN=""
MODE="dry-run"
ACTION="install"
LOG_LINES=80

usage() {
  cat <<'USAGE'
Usage: install-launchd-controller-guide.sh [options]

Install and inspect the controller guide LaunchAgent.

Options:
  --apply             Write and load the LaunchAgent (default is dry-run)
  --dry-run           Print the LaunchAgent plist without changing the system
  --uninstall         Select uninstall; combine with --apply to remove it
  --status            Print launchd status and the local health response
  --logs [n]          Tail launchd logs (default: 80 lines)
  --label <label>     Override the LaunchAgent label
  --port <port>       Override the loopback port (default: 8798)
  --python <path>     Override the Python executable
  --no-input          Assert non-interactive operation (accepted for automation)
  -h, --help          Show this help

Examples:
  scripts/install-launchd-controller-guide.sh
  scripts/install-launchd-controller-guide.sh --apply --no-input
  scripts/install-launchd-controller-guide.sh --status --no-input
  scripts/install-launchd-controller-guide.sh --logs 150 --no-input
  scripts/install-launchd-controller-guide.sh --uninstall --apply --no-input
USAGE
}

die_usage() {
  printf 'ERROR: %s\n' "$*" >&2
  usage >&2
  exit 2
}

is_port() {
  [[ "${1:-}" =~ ^[0-9]+$ ]] && (( 1 <= 10#$1 && 10#$1 <= 65535 ))
}

is_uint() {
  [[ "${1:-}" =~ ^[0-9]+$ ]]
}

xml_escape() {
  local value="$1"
  value="${value//&/&amp;}"
  value="${value//</&lt;}"
  value="${value//>/&gt;}"
  printf '%s' "$value"
}

resolve_python() {
  if [[ -n "$PYTHON_BIN" ]]; then
    return
  fi

  local resolver="${HOME}/GitHub/scripts/setup/codex/resolve-preferred-homebrew-python.sh"
  if [[ -x "$resolver" ]]; then
    PYTHON_BIN="$($resolver --output python-shim 2>/dev/null || true)"
  fi
  if [[ -z "$PYTHON_BIN" ]]; then
    PYTHON_BIN="$(command -v python3 || true)"
  fi
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
    --uninstall)
      ACTION="uninstall"
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
    --label)
      [[ -n "${2:-}" ]] || die_usage "--label requires a value"
      LABEL="$2"
      shift 2
      ;;
    --port)
      [[ -n "${2:-}" ]] || die_usage "--port requires a value"
      PORT="$2"
      shift 2
      ;;
    --python)
      [[ -n "${2:-}" ]] || die_usage "--python requires a value"
      PYTHON_BIN="$2"
      shift 2
      ;;
    --no-input)
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die_usage "unknown option: $1"
      ;;
  esac
done

[[ -n "$LABEL" ]] || die_usage "label cannot be empty"
is_port "$PORT" || die_usage "invalid port: $PORT"
is_uint "$LOG_LINES" || die_usage "invalid log line count: $LOG_LINES"

PLIST_PATH="${HOME}/Library/LaunchAgents/${LABEL}.plist"
STATE_DIR="${HOME}/.local/state/stadia-controller-guide"
LOG_DIR="${STATE_DIR}/log"
OUT_LOG="${LOG_DIR}/launchd.out.log"
ERR_LOG="${LOG_DIR}/launchd.err.log"
DOMAIN="gui/$(id -u)"
HEALTH_URL="http://127.0.0.1:${PORT}/api/health"

print_status() {
  launchctl print "${DOMAIN}/${LABEL}"
  printf '\nHealth: '
  curl --fail --silent --show-error --max-time 3 "$HEALTH_URL"
  printf '\n'
}

if [[ "$ACTION" == "status" ]]; then
  print_status
  exit $?
fi

if [[ "$ACTION" == "logs" ]]; then
  printf '[stdout] %s\n' "$OUT_LOG"
  tail -n "$LOG_LINES" "$OUT_LOG" 2>/dev/null || true
  printf '[stderr] %s\n' "$ERR_LOG"
  tail -n "$LOG_LINES" "$ERR_LOG" 2>/dev/null || true
  exit 0
fi

if [[ "$ACTION" == "uninstall" ]]; then
  if [[ "$MODE" == "dry-run" ]]; then
    printf 'Would unload %s and remove %s\n' "$LABEL" "$PLIST_PATH"
    exit 0
  fi
  launchctl bootout "${DOMAIN}/${LABEL}" >/dev/null 2>&1 || true
  rm -f "$PLIST_PATH"
  printf 'Uninstalled %s\n' "$LABEL"
  exit 0
fi

resolve_python
[[ -x "$PYTHON_BIN" ]] || {
  printf 'ERROR: Python executable not found: %s\n' "${PYTHON_BIN:-<unresolved>}" >&2
  exit 1
}
[[ -f "$ROOT_DIR/scripts/serve-controller-guide.py" ]] || {
  printf 'ERROR: guide server not found under %s\n' "$ROOT_DIR" >&2
  exit 1
}

render_plist() {
  cat <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>$(xml_escape "$LABEL")</string>
    <key>ProgramArguments</key>
    <array>
      <string>$(xml_escape "$PYTHON_BIN")</string>
      <string>$(xml_escape "$ROOT_DIR/scripts/serve-controller-guide.py")</string>
      <string>--port</string>
      <string>$(xml_escape "$PORT")</string>
    </array>
    <key>WorkingDirectory</key>
    <string>$(xml_escape "$ROOT_DIR")</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ThrottleInterval</key>
    <integer>60</integer>
    <key>StandardOutPath</key>
    <string>$(xml_escape "$OUT_LOG")</string>
    <key>StandardErrorPath</key>
    <string>$(xml_escape "$ERR_LOG")</string>
    <key>EnvironmentVariables</key>
    <dict>
      <key>HOME</key>
      <string>$(xml_escape "$HOME")</string>
      <key>PATH</key>
      <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
      <key>PYTHONUNBUFFERED</key>
      <string>1</string>
    </dict>
  </dict>
</plist>
PLIST
}

if [[ "$MODE" == "dry-run" ]]; then
  render_plist
  exit 0
fi

mkdir -p "$(dirname "$PLIST_PATH")" "$LOG_DIR"
render_plist >"$PLIST_PATH"
chmod 0644 "$PLIST_PATH"

launchctl bootout "${DOMAIN}/${LABEL}" >/dev/null 2>&1 || true
launchctl bootstrap "$DOMAIN" "$PLIST_PATH"

for _ in {1..30}; do
  if curl --fail --silent --show-error --max-time 2 "$HEALTH_URL" >/dev/null 2>&1; then
    printf 'Loaded %s from %s\n' "$LABEL" "$PLIST_PATH"
    printf 'Health: %s\n' "$HEALTH_URL"
    printf 'Logs: %s and %s\n' "$OUT_LOG" "$ERR_LOG"
    exit 0
  fi
  sleep 0.2
done

printf 'ERROR: %s loaded but did not become healthy at %s\n' "$LABEL" "$HEALTH_URL" >&2
tail -n 40 "$ERR_LOG" >&2 2>/dev/null || true
exit 5
