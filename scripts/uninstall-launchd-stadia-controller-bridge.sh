#!/usr/bin/env bash
set -euo pipefail

LABEL="com.${USER}.stadia-controller-bridge"
PLIST_PATH="${HOME}/Library/LaunchAgents/${LABEL}.plist"

if [[ "${1:-}" == "--label" ]]; then
  LABEL="${2:-}"
  PLIST_PATH="${HOME}/Library/LaunchAgents/${LABEL}.plist"
fi

DOMAIN="gui/$(id -u)"
launchctl bootout "$DOMAIN" "$PLIST_PATH" >/dev/null 2>&1 || true
rm -f "$PLIST_PATH"

echo "Unloaded and removed ${LABEL} (${PLIST_PATH})"
