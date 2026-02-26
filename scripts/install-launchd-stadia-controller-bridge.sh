#!/usr/bin/env bash
set -euo pipefail

LABEL="com.${USER}.stadia-controller-bridge"
REPO_DIR="${HOME}/GitHub/stadia-macos-controller"
CONFIG_PATH="config/mappings.json"
BINARY_PATH=""
MODE="live"   # live|dry-run
START_INTERVAL=0
RUN_AT_LOAD=1

PLIST_PATH="${HOME}/Library/LaunchAgents/${LABEL}.plist"
OUT_LOG="${HOME}/Library/Logs/stadia-controller-bridge.launchd.out.log"
ERR_LOG="${HOME}/Library/Logs/stadia-controller-bridge.launchd.err.log"

usage() {
  cat <<USAGE
Usage: $(basename "$0") [options]

Install/update a launchd job for the Stadia macOS controller bridge.

Options:
  --label <label>           LaunchAgent label (default: com.<user>.stadia-controller-bridge)
  --repo-dir <path>         Repo path (default: ~/GitHub/stadia-macos-controller)
  --config <path>           Config path relative to repo dir (default: config/mappings.json)
  --binary <path>           Binary path (default: <repo>/.build/debug/stadia-controller-bridge)
  --mode <live|dry-run>     Bridge mode (default: live)
  --start-interval <sec>    Optional restart interval in seconds (0 disables)
  --no-run-at-load          Disable RunAtLoad
  --help                    Show help

Examples:
  ./scripts/install-launchd-stadia-controller-bridge.sh
  ./scripts/install-launchd-stadia-controller-bridge.sh --mode dry-run
  ./scripts/install-launchd-stadia-controller-bridge.sh --repo-dir ~/GitHub/stadia-macos-controller
USAGE
}

is_int() {
  [[ "$1" =~ ^[0-9]+$ ]]
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --label)
      LABEL="${2:-}"
      PLIST_PATH="${HOME}/Library/LaunchAgents/${LABEL}.plist"
      shift 2
      ;;
    --repo-dir)
      REPO_DIR="${2:-}"
      shift 2
      ;;
    --config)
      CONFIG_PATH="${2:-}"
      shift 2
      ;;
    --binary)
      BINARY_PATH="${2:-}"
      shift 2
      ;;
    --mode)
      MODE="${2:-}"
      shift 2
      ;;
    --start-interval)
      START_INTERVAL="${2:-}"
      shift 2
      ;;
    --no-run-at-load)
      RUN_AT_LOAD=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$MODE" != "live" && "$MODE" != "dry-run" ]]; then
  echo "Invalid --mode: $MODE (expected live or dry-run)" >&2
  exit 2
fi

if ! is_int "$START_INTERVAL"; then
  echo "Invalid --start-interval: $START_INTERVAL (expected integer >= 0)" >&2
  exit 2
fi

if [[ ! -d "$REPO_DIR" ]]; then
  echo "Repo dir not found: $REPO_DIR" >&2
  exit 1
fi

if [[ ! -f "$REPO_DIR/$CONFIG_PATH" ]]; then
  echo "Config file not found: $REPO_DIR/$CONFIG_PATH" >&2
  exit 1
fi

if [[ -z "$BINARY_PATH" ]]; then
  BINARY_PATH="${REPO_DIR}/.build/debug/stadia-controller-bridge"
fi

if [[ ! -x "$BINARY_PATH" ]]; then
  echo "Bridge binary not found at $BINARY_PATH; building debug binary first..."
  (cd "$REPO_DIR" && swift build >/dev/null)
fi

if [[ ! -x "$BINARY_PATH" ]]; then
  echo "Bridge binary missing after build: $BINARY_PATH" >&2
  exit 1
fi

mkdir -p "$(dirname "$PLIST_PATH")"
mkdir -p "$(dirname "$OUT_LOG")"

mode_args="--no-dry-run"
if [[ "$MODE" == "dry-run" ]]; then
  mode_args="--dry-run"
fi

CONFIG_ABS_PATH="${REPO_DIR}/${CONFIG_PATH}"

start_interval_xml=""
if (( START_INTERVAL > 0 )); then
  start_interval_xml=$(cat <<XML
    <key>StartInterval</key>
    <integer>${START_INTERVAL}</integer>
XML
)
fi

run_at_load_xml=""
if (( RUN_AT_LOAD == 1 )); then
  run_at_load_xml=$(cat <<XML
    <key>RunAtLoad</key>
    <true/>
XML
)
fi

cat >"$PLIST_PATH" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>${LABEL}</string>

    <key>ProgramArguments</key>
    <array>
      <string>${BINARY_PATH}</string>
      <string>--config</string>
      <string>${CONFIG_ABS_PATH}</string>
      <string>${mode_args}</string>
    </array>

    <key>KeepAlive</key>
    <true/>

${run_at_load_xml}
${start_interval_xml}

    <key>WorkingDirectory</key>
    <string>${REPO_DIR}</string>

    <key>StandardOutPath</key>
    <string>${OUT_LOG}</string>

    <key>StandardErrorPath</key>
    <string>${ERR_LOG}</string>

    <key>EnvironmentVariables</key>
    <dict>
      <key>PATH</key>
      <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
      <key>HOME</key>
      <string>${HOME}</string>
    </dict>
  </dict>
</plist>
PLIST

chmod 0644 "$PLIST_PATH"

DOMAIN="gui/$(id -u)"
launchctl bootout "$DOMAIN" "$PLIST_PATH" >/dev/null 2>&1 || true
launchctl bootstrap "$DOMAIN" "$PLIST_PATH"
launchctl kickstart -k "$DOMAIN/$LABEL" >/dev/null 2>&1 || true

echo "Loaded $LABEL from $PLIST_PATH"
echo "Mode: $MODE"
echo "Logs:"
echo "  $OUT_LOG"
echo "  $ERR_LOG"
echo "Status:"
launchctl print "$DOMAIN/$LABEL" | sed -n '1,90p'
