#!/usr/bin/env python3
"""Exercise the local controller guide server without external dependencies."""

from __future__ import annotations

import importlib.util
import json
import plistlib
import subprocess
import sys
import threading
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import urlopen


sys.dont_write_bytecode = True


REPO_ROOT = Path(__file__).resolve().parents[1]
SERVER_PATH = REPO_ROOT / "scripts" / "serve-controller-guide.py"
DEPLOY_PATH = REPO_ROOT / "scripts" / "deploy-controller-guide.sh"
INSTALLER_PATH = REPO_ROOT / "scripts" / "install-launchd-controller-guide.sh"


def load_server_module():
    spec = importlib.util.spec_from_file_location("controller_guide_server", SERVER_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to import {SERVER_PATH}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def fetch(url: str) -> tuple[int, str, bytes]:
    with urlopen(url, timeout=3) as response:  # noqa: S310 - loopback test server
        return response.status, response.headers.get_content_type(), response.read()


def check_deploy_contract() -> None:
    dry_run = subprocess.run(
        [str(DEPLOY_PATH), "--json", "--no-input"],
        capture_output=True,
        check=False,
        text=True,
    )
    assert dry_run.returncode == 0, dry_run.stderr
    payload = json.loads(dry_run.stdout)
    assert payload["schema_version"] == "1.0"
    assert payload["command"] == "deploy-controller-guide"
    assert payload["status"] == "ok"
    assert payload["data"]["mode"] == "dry-run"
    assert payload["error"] is None

    invalid = subprocess.run(
        [str(DEPLOY_PATH), "--invalid"],
        capture_output=True,
        check=False,
        text=True,
    )
    assert invalid.returncode == 2
    invalid_payload = json.loads(invalid.stdout)
    assert invalid_payload["status"] == "error"
    assert invalid_payload["error"]["code"] == "E_INVALID_USAGE"

    installer = subprocess.run(
        [str(INSTALLER_PATH), "--dry-run", "--no-input"],
        capture_output=True,
        check=False,
    )
    assert installer.returncode == 0, installer.stderr.decode()
    plist = plistlib.loads(installer.stdout)
    assert plist["Label"].endswith(".stadia-controller-guide")
    assert plist["RunAtLoad"] is True
    assert plist["KeepAlive"] is True
    assert plist["ProgramArguments"][-2:] == ["--port", "8798"]


def main() -> int:
    module = load_server_module()
    server = module.create_server("127.0.0.1", 0)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    port = server.server_address[1]
    base_url = f"http://127.0.0.1:{port}"

    try:
        status, content_type, body = fetch(f"{base_url}/")
        assert status == 200
        assert content_type == "text/html"
        assert b'id="controller-map"' in body

        status, content_type, body = fetch(f"{base_url}/api/mappings")
        assert status == 200
        assert content_type == "application/json"
        served = json.loads(body)
        expected = json.loads((REPO_ROOT / "config" / "mappings.json").read_text())
        assert served == expected

        status, content_type, body = fetch(f"{base_url}/api/health")
        assert status == 200
        assert content_type == "application/json"
        assert json.loads(body) == {
            "status": "ok",
            "config": "config/mappings.json",
        }

        for path, expected_type in (
            ("/styles.css", "text/css"),
            ("/boot.js", "text/javascript"),
            ("/app.js", "text/javascript"),
        ):
            status, content_type, _ = fetch(f"{base_url}{path}")
            assert status == 200
            assert content_type == expected_type

        try:
            fetch(f"{base_url}/package.swift")
        except HTTPError as error:
            assert error.code == 404
        else:
            raise AssertionError("Server exposed a route outside the guide allowlist")
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=3)

    node = subprocess.run(
        ["sh", "-c", "command -v node"],
        capture_output=True,
        check=False,
        text=True,
    ).stdout.strip()
    if node:
        subprocess.run([node, "--check", str(REPO_ROOT / "guide" / "boot.js")], check=True)
        subprocess.run([node, "--check", str(REPO_ROOT / "guide" / "app.js")], check=True)

    check_deploy_contract()

    print(
        "[check-controller-guide] routes, live config, isolation, JavaScript, "
        "and deploy contracts passed"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, OSError, ValueError) as error:
        print(f"[check-controller-guide] failed: {error}", file=sys.stderr)
        raise SystemExit(1) from error
