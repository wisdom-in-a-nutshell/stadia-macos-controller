#!/usr/bin/env bash
set -euo pipefail

LABEL="com.${USER}.stadia-controller-bridge"
REPO_DIR="${HOME}/GitHub/stadia-macos-controller"
CONFIG_PATH="config/mappings.json"
BINARY_PATH=""
MODE="live"   # live|dry-run
START_INTERVAL=0
RUN_AT_LOAD=1
BUILD_CONFIG="release" # release|debug
RUNTIME_DIR="${HOME}/Library/Application Support/stadia-controller-bridge"
SIGN_IDENTITY="adhoc"  # auto|adhoc|none|<identity string>
SIGNING_IDENTIFIER="com.${USER}.stadia-controller-bridge"
FORCE_BUILD=0

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
  --binary <path>           Use explicit binary path (skip build/stage pipeline)
  --mode <live|dry-run>     Bridge mode (default: live)
  --build <release|debug>   Build config when --binary is not provided (default: release)
  --force-build             Force rebuild/restage even if staged binary is already fresh
  --runtime-dir <path>      Stable runtime dir for staged binary (default: ~/Library/Application Support/stadia-controller-bridge)
  --sign-identity <value>   Code-sign identity: auto | adhoc | none | "Apple Development: ..."
  --signing-id <id>         Code-sign identifier (default: com.<user>.stadia-controller-bridge)
  --start-interval <sec>    Optional restart interval in seconds (0 disables)
  --no-run-at-load          Disable RunAtLoad
  --help                    Show help

Examples:
  ./scripts/install-launchd-stadia-controller-bridge.sh
  ./scripts/install-launchd-stadia-controller-bridge.sh --sign-identity adhoc
  ./scripts/install-launchd-stadia-controller-bridge.sh --sign-identity "Apple Development: Your Name (TEAMID)"
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
    --build)
      BUILD_CONFIG="${2:-}"
      shift 2
      ;;
    --force-build)
      FORCE_BUILD=1
      shift
      ;;
    --runtime-dir)
      RUNTIME_DIR="${2:-}"
      shift 2
      ;;
    --sign-identity)
      SIGN_IDENTITY="${2:-}"
      shift 2
      ;;
    --signing-id)
      SIGNING_IDENTIFIER="${2:-}"
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

if [[ "$BUILD_CONFIG" != "release" && "$BUILD_CONFIG" != "debug" ]]; then
  echo "Invalid --build: $BUILD_CONFIG (expected release or debug)" >&2
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

STAGED_DIR="${RUNTIME_DIR}/bin"
STAGED_BINARY="${STAGED_DIR}/stadia-controller-bridge"
SKIP_SIGN=0

if [[ -z "$BINARY_PATH" ]]; then
  NEED_BUILD=1
  if (( FORCE_BUILD == 0 )) && [[ -x "$STAGED_BINARY" ]]; then
    if ! find "$REPO_DIR/Package.swift" "$REPO_DIR/src" -type f -newer "$STAGED_BINARY" -print -quit | grep -q .; then
      NEED_BUILD=0
    fi
  fi

  if (( NEED_BUILD == 1 )); then
    echo "Building ${BUILD_CONFIG} binary..."
    (cd "$REPO_DIR" && swift build -c "$BUILD_CONFIG" >/dev/null)
    BIN_DIR="$(cd "$REPO_DIR" && swift build -c "$BUILD_CONFIG" --show-bin-path)"
    BUILT_BINARY="${BIN_DIR}/stadia-controller-bridge"
    if [[ ! -x "$BUILT_BINARY" ]]; then
      echo "Built binary missing: $BUILT_BINARY" >&2
      exit 1
    fi

    mkdir -p "$STAGED_DIR"
    /usr/bin/install -m 0755 "$BUILT_BINARY" "$STAGED_BINARY"
    BINARY_PATH="$STAGED_BINARY"
    echo "Staged runtime binary at: $BINARY_PATH"
  else
    BINARY_PATH="$STAGED_BINARY"
    SKIP_SIGN=1
    echo "Reusing existing staged binary (no source changes detected): $BINARY_PATH"
  fi
elif [[ "$BINARY_PATH" != /* ]]; then
  BINARY_PATH="${REPO_DIR}/${BINARY_PATH}"
fi

if [[ ! -x "$BINARY_PATH" ]]; then
  echo "Bridge binary not executable: $BINARY_PATH" >&2
  exit 1
fi

resolve_identity() {
  local requested="$1"
  if [[ "$requested" == "none" ]]; then
    echo ""
    return 0
  fi

  if [[ "$requested" == "adhoc" ]]; then
    echo "-"
    return 0
  fi

  if [[ "$requested" == "auto" ]]; then
    local identities
    identities="$(security find-identity -v -p codesigning 2>/dev/null | sed -n 's/.*"\(.*\)"/\1/p' || true)"
    local selected
    selected="$(printf '%s\n' "$identities" | awk '/^Developer ID Application:/{print; exit}')"
    if [[ -z "$selected" ]]; then
      selected="$(printf '%s\n' "$identities" | awk '/^Apple Development:/{print; exit}')"
    fi
    if [[ -z "$selected" ]]; then
      selected="$(printf '%s\n' "$identities" | awk 'NF{print; exit}')"
    fi
    if [[ -z "$selected" ]]; then
      echo "-"
      return 0
    fi
    echo "$selected"
    return 0
  fi

  echo "$requested"
}

if (( SKIP_SIGN == 1 )); then
  echo "Skipping code-sign step for reused staged binary to preserve existing Accessibility trust."
  SELECTED_IDENTITY="(unchanged)"
else
  SELECTED_IDENTITY="$(resolve_identity "$SIGN_IDENTITY")"
  if [[ -n "$SELECTED_IDENTITY" ]]; then
    echo "Signing binary with identity: ${SELECTED_IDENTITY}"
    if ! /usr/bin/codesign --force --sign "$SELECTED_IDENTITY" --identifier "$SIGNING_IDENTIFIER" "$BINARY_PATH"; then
      if [[ "$SIGN_IDENTITY" == "auto" && "$SELECTED_IDENTITY" != "-" ]]; then
        echo "WARN: auto identity signing failed; falling back to ad-hoc signing (-)." >&2
        /usr/bin/codesign --force --sign - --identifier "$SIGNING_IDENTIFIER" "$BINARY_PATH"
        SELECTED_IDENTITY="-"
      else
        echo "ERROR: code signing failed for identity: ${SELECTED_IDENTITY}" >&2
        exit 1
      fi
    fi
  else
    SELECTED_IDENTITY="(none)"
    echo "Code signing disabled (--sign-identity none)."
  fi
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
echo "Binary: $BINARY_PATH"
if [[ -n "${SELECTED_IDENTITY}" ]]; then
  echo "Code signature:"
  /usr/bin/codesign -dv --verbose=2 "$BINARY_PATH" 2>&1 | sed -n '1,14p'
fi
echo "Logs:"
echo "  $OUT_LOG"
echo "  $ERR_LOG"
echo "Status:"
launchctl print "$DOMAIN/$LABEL" | sed -n '1,90p'
