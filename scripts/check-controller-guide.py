#!/usr/bin/env python3
"""Exercise the local controller guide server without external dependencies."""

from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
import tempfile
import threading
from dataclasses import replace
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import urlopen


sys.dont_write_bytecode = True


REPO_ROOT = Path(__file__).resolve().parents[1]
SERVER_PATH = REPO_ROOT / "scripts" / "serve-controller-guide.py"
DEPLOY_PATH = REPO_ROOT / "scripts" / "deploy-controller-guide.sh"
DEPLOY_MODULE_PATH = REPO_ROOT / "scripts" / "deploy_controller_guide.py"


def load_server_module():
    spec = importlib.util.spec_from_file_location("controller_guide_server", SERVER_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to import {SERVER_PATH}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def load_deploy_module():
    spec = importlib.util.spec_from_file_location(
        "controller_guide_deploy", DEPLOY_MODULE_PATH
    )
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Unable to import {DEPLOY_MODULE_PATH}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
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
    assert payload["data"]["source_contract"] == "clean-main-exact-sha"
    assert payload["data"]["activation"] == "versioned-health-gated"
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

    plain = subprocess.run(
        [str(DEPLOY_PATH), "--plain", "--no-input"],
        capture_output=True,
        check=False,
        text=True,
    )
    assert plain.returncode == 0, plain.stderr
    assert plain.stdout.startswith(
        "status=ok action=dry-run service=stadia-controller-guide target=production"
    )

    status = subprocess.run(
        [str(DEPLOY_PATH), "--status", "--json", "--no-input"],
        capture_output=True,
        check=False,
        text=True,
    )
    assert status.returncode == 0, status.stderr
    status_payload = json.loads(status.stdout)
    assert status_payload["status"] == "ok"
    assert status_payload["data"]["action"] == "status"
    assert set(status_payload["data"]) == {
        "action",
        "current_release",
        "current_source",
        "health",
        "launchd",
        "launchd_label",
        "local_url",
        "mode",
        "previous_release",
        "public_url",
        "service",
        "target",
        "timeout_seconds",
    }
    assert "environment" not in status.stdout.lower()

    configured = subprocess.run(
        [
            str(DEPLOY_PATH),
            "--json",
            "--no-input",
            "--timeout",
            "12",
            "--progress",
            "off",
        ],
        capture_output=True,
        check=False,
        text=True,
    )
    assert configured.returncode == 0, configured.stderr
    configured_payload = json.loads(configured.stdout)
    assert configured_payload["data"]["timeout_seconds"] == 12
    assert configured.stderr == ""

    logs = subprocess.run(
        [str(DEPLOY_PATH), "--logs", "2", "--json", "--no-input"],
        capture_output=True,
        check=False,
        text=True,
    )
    assert logs.returncode == 0, logs.stderr
    logs_payload = json.loads(logs.stdout)
    assert logs_payload["status"] == "ok"
    assert logs_payload["data"]["requested_lines"] == 2
    assert len(logs_payload["data"]["stdout"]) <= 2
    assert len(logs_payload["data"]["stderr"]) <= 2
    assert invalid_payload["error"]["hint"]


def check_deploy_internals() -> None:
    module = load_deploy_module()

    with tempfile.TemporaryDirectory(
        prefix="controller-guide-source-test.", dir=REPO_ROOT / "tmp"
    ) as directory:
        repo = Path(directory) / "repo"
        subprocess.run(["git", "init", "-q", "-b", "main", str(repo)], check=True)
        subprocess.run(
            ["git", "-C", str(repo), "config", "user.name", "Controller Guide Test"],
            check=True,
        )
        subprocess.run(
            [
                "git",
                "-C",
                str(repo),
                "config",
                "user.email",
                "controller-guide-test@example.invalid",
            ],
            check=True,
        )
        tracked = repo / "tracked.txt"
        tracked.write_text("first\n", encoding="utf-8")
        subprocess.run(["git", "-C", str(repo), "add", "tracked.txt"], check=True)
        subprocess.run(
            ["git", "-C", str(repo), "commit", "-q", "-m", "initial"], check=True
        )

        snapshot = module.capture_clean_source(repo)
        module.verify_clean_source(repo, snapshot)

        tracked.write_text("dirty\n", encoding="utf-8")
        try:
            module.verify_clean_source(repo, snapshot)
        except module.ClientError as error:
            assert error.code == "E_SOURCE_CHANGED"
        else:
            raise AssertionError("Dirty source passed production verification")
        subprocess.run(
            ["git", "-C", str(repo), "checkout", "-q", "--", "tracked.txt"],
            check=True,
        )

        subprocess.run(
            ["git", "-C", str(repo), "checkout", "-q", "-b", "feature"], check=True
        )
        try:
            module.capture_clean_source(repo)
        except module.ClientError as error:
            assert error.code == "E_SOURCE_CONTRACT"
        else:
            raise AssertionError("Wrong branch passed production source capture")
        subprocess.run(
            ["git", "-C", str(repo), "checkout", "-q", "main"], check=True
        )

        tracked.write_text("second\n", encoding="utf-8")
        subprocess.run(["git", "-C", str(repo), "add", "tracked.txt"], check=True)
        subprocess.run(
            ["git", "-C", str(repo), "commit", "-q", "-m", "second"], check=True
        )
        try:
            module.verify_clean_source(repo, snapshot)
        except module.ClientError as error:
            assert error.code == "E_SOURCE_CHANGED"
        else:
            raise AssertionError("Moved source passed production verification")

    paths = module.default_paths(REPO_ROOT)
    plist = module.plist_payload(paths, Path(sys.executable).resolve())
    assert "EnvironmentVariables" not in plist
    assert plist["ProgramArguments"][:2] == ["/usr/bin/env", "-i"]
    assert str(REPO_ROOT) not in " ".join(plist["ProgramArguments"])
    assert plist["ProgramArguments"][-2:] == ["--port", "8798"]
    assert (
        module.sanitize_log_line(
            'GET /?token=sensitive HTTP/1.1 password=also-sensitive'
        )
        == 'GET /?[redacted] HTTP/1.1 password=[redacted]'
    )

    with tempfile.TemporaryDirectory(
        prefix="controller-guide-release-test.", dir=REPO_ROOT / "tmp"
    ) as directory:
        release = Path(directory) / "release"
        release.mkdir()
        module.copy_release_source(REPO_ROOT, release, "a" * 40)
        module.make_read_only(release)
        assert (release / "guide/index.html").is_file()
        assert (release / "config/mappings.json").is_file()
        assert (release / "scripts/serve-controller-guide.py").is_file()
        assert not (release.stat().st_mode & 0o222)
        assert all(not (path.stat().st_mode & 0o222) for path in release.rglob("*"))
        # Restore owner write permission so TemporaryDirectory can remove the fixture.
        for path in release.rglob("*"):
            if path.is_dir():
                path.chmod(0o755)
        release.chmod(0o755)


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
            "source_sha": "unreleased",
        }
        deploy_module = load_deploy_module()
        health_paths = replace(
            deploy_module.default_paths(REPO_ROOT),
            health_url=f"{base_url}/api/health",
        )
        assert deploy_module.health_is_ok(health_paths)
        assert deploy_module.health_is_ok(
            health_paths, expected_source="unreleased"
        )
        assert not deploy_module.health_is_ok(
            health_paths, expected_source="wrong-revision"
        )

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
    check_deploy_internals()

    print(
        "[check-controller-guide] routes, live config, isolation, JavaScript, "
        "JSON client, source stability, safe status/logs, and plist contracts passed"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AssertionError, OSError, ValueError) as error:
        print(f"[check-controller-guide] failed: {error}", file=sys.stderr)
        raise SystemExit(1) from error
