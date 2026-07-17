#!/usr/bin/env python3
"""Fast static checks for controller mapping actions."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parent.parent
CONFIG_PATH = ROOT / "config" / "mappings.json"
KNOWN_ACTION_TYPES = {
    "applescript",
    "ghosttyAction",
    "holdKeystroke",
    "keystroke",
    "modifierChord",
    "mouseClick",
    "shell",
    "text",
}
LABEL_BOUND_MENU_CLICK = re.compile(r"\bclick\s+menu item\s+\"", re.IGNORECASE)
LOW_LATENCY_CODEX_ACTION_TYPES = {"holdKeystroke", "keystroke"}


def iter_actions(value: Any, path: str = "config"):
    if isinstance(value, dict):
        if isinstance(value.get("type"), str):
            yield path, value
        for key, child in value.items():
            yield from iter_actions(child, f"{path}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            yield from iter_actions(child, f"{path}[{index}]")


def validate_action(path: str, action: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    action_type = action["type"]

    if action_type not in KNOWN_ACTION_TYPES:
        errors.append(f"{path}: unknown action type {action_type!r}")
        return errors

    if action_type == "applescript":
        script = action.get("script")
        if isinstance(script, str) and LABEL_BOUND_MENU_CLICK.search(script):
            errors.append(
                f"{path}: label-bound menu AppleScript is forbidden; use a direct keystroke"
            )

    return errors


def validate_codex_latency(config: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    mappings = config.get("profiles", {}).get("codexApp", {}).get("mappings", {})
    if not isinstance(mappings, dict):
        return ["config.profiles.codexApp.mappings: expected an object"]

    for button, mapping in mappings.items():
        action_type = mapping.get("action", {}).get("type") if isinstance(mapping, dict) else None
        if action_type not in LOW_LATENCY_CODEX_ACTION_TYPES:
            errors.append(
                f"config.profiles.codexApp.mappings.{button}.action: "
                f"Codex button mappings must stay on the low-latency keystroke path, got {action_type!r}"
            )
    return errors


def main() -> int:
    try:
        config = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        print(f"[check-mappings] failed to load {CONFIG_PATH}: {error}", file=sys.stderr)
        return 1

    actions = list(iter_actions(config))
    errors = [
        error
        for path, action in actions
        for error in validate_action(path, action)
    ]
    errors.extend(validate_codex_latency(config))
    if errors:
        for error in errors:
            print(f"[check-mappings] ERROR: {error}", file=sys.stderr)
        return 1

    codex_mapping_count = len(config["profiles"]["codexApp"]["mappings"])
    print(f"[check-mappings] passed actions={len(actions)} codexLowLatency={codex_mapping_count}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
