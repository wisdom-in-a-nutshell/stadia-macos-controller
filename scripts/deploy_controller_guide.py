#!/usr/bin/env python3
"""Deploy the controller guide as an exact-source, versioned Mac Mini release."""

from __future__ import annotations

import datetime as dt
import json
import os
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import time
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import NoReturn
from urllib.error import URLError
from urllib.request import urlopen


SCHEMA_VERSION = "1.0"
SERVICE = "stadia-controller-guide"
COMMAND = "deploy-controller-guide"
TARGET = "production"
HOST = "127.0.0.1"
PORT = 8798
PUBLIC_URL = "https://controller.adithyan.io/"
HEALTH_WAIT_SECONDS = 30.0
MAX_LOG_LINES = 500
MAX_LOG_LINE_LENGTH = 2_000
SAFE_NAME = re.compile(r"^[A-Za-z0-9._-]+$")


class ClientError(RuntimeError):
    def __init__(
        self,
        code: str,
        message: str,
        *,
        exit_code: int = 1,
        retryable: bool = False,
    ) -> None:
        super().__init__(message)
        self.code = code
        self.message = message
        self.exit_code = exit_code
        self.retryable = retryable


@dataclass(frozen=True)
class SourceSnapshot:
    branch: str
    sha: str


@dataclass(frozen=True)
class RuntimePaths:
    repo_root: Path
    release_root: Path
    releases_dir: Path
    current_link: Path
    previous_link: Path
    state_root: Path
    log_dir: Path
    stdout_log: Path
    stderr_log: Path
    plist_path: Path
    label: str
    domain: str
    health_url: str


@dataclass
class Options:
    action: str = "dry-run"
    output_format: str = "json"
    log_lines: int = 80
    target: str = TARGET
    timeout_seconds: float = HEALTH_WAIT_SECONDS
    progress: str = "plain"


def default_paths(repo_root: Path) -> RuntimePaths:
    home = Path.home()
    release_root = home / ".local/share/stadia-controller-guide/production"
    state_root = home / ".local/state/stadia-controller-guide"
    username = os.environ.get("USER", "")
    if not SAFE_NAME.fullmatch(username):
        username = f"user{os.getuid()}"
    label = f"com.{username}.stadia-controller-guide"
    return RuntimePaths(
        repo_root=repo_root,
        release_root=release_root,
        releases_dir=release_root / "releases",
        current_link=release_root / "current",
        previous_link=release_root / "previous",
        state_root=state_root,
        log_dir=state_root / "log",
        stdout_log=state_root / "log/launchd.out.log",
        stderr_log=state_root / "log/launchd.err.log",
        plist_path=home / f"Library/LaunchAgents/{label}.plist",
        label=label,
        domain=f"gui/{os.getuid()}",
        health_url=f"http://{HOST}:{PORT}/api/health",
    )


def usage() -> str:
    return """Usage: deploy-controller-guide.sh [action] [options]

Actions:
  --apply                 Run the full gate, activate, and prove production
  --dry-run               Return the deployment plan without mutation (default)
  --status                Return allowlisted release, launchd, and health state
  --logs [n]              Return sanitized recent logs (default: 80; max: 500)
  --rollback              Restore and prove the previous release
  --uninstall             Unload the LaunchAgent but retain releases

Options:
  --target production     Explicit production target
  --json                  Emit one JSON result object on stdout (default)
  --plain                 Emit compact stable text on stdout
  --no-input              Assert noninteractive operation
  --timeout <seconds>     Health-proof timeout (default: 30; range: 1-600)
  --progress off|plain    Stderr progress mode (default: plain)
  -h, --help              Show help

Exit codes:
  0  Success
  1  Source, validation, packaging, or activation failure
  2  Invalid usage
  5  Health proof failed
  6  Rollback failed

Examples:
  scripts/deploy-controller-guide.sh
  scripts/deploy-controller-guide.sh --status --json --no-input
  scripts/deploy-controller-guide.sh --apply --plain --no-input
  scripts/deploy-controller-guide.sh --rollback --json --no-input
"""


def parse_args(argv: list[str]) -> Options | None:
    options = Options()
    action_seen = False
    index = 0

    def select_action(action: str) -> None:
        nonlocal action_seen
        if action_seen:
            raise ClientError(
                "E_INVALID_USAGE",
                f"actions cannot be combined: {options.action} and {action}",
                exit_code=2,
            )
        options.action = action
        action_seen = True

    while index < len(argv):
        argument = argv[index]
        if argument in {"-h", "--help"}:
            print(usage(), end="")
            return None
        if argument == "--apply":
            select_action("apply")
        elif argument == "--dry-run":
            select_action("dry-run")
        elif argument == "--status":
            select_action("status")
        elif argument == "--rollback":
            select_action("rollback")
        elif argument == "--uninstall":
            select_action("uninstall")
        elif argument == "--logs":
            select_action("logs")
            if index + 1 < len(argv) and not argv[index + 1].startswith("--"):
                index += 1
                try:
                    options.log_lines = int(argv[index])
                except ValueError as error:
                    raise ClientError(
                        "E_INVALID_USAGE",
                        f"invalid log line count: {argv[index]}",
                        exit_code=2,
                    ) from error
        elif argument == "--target":
            if index + 1 >= len(argv):
                raise ClientError(
                    "E_INVALID_USAGE", "--target requires a value", exit_code=2
                )
            index += 1
            options.target = argv[index]
        elif argument == "--json":
            options.output_format = "json"
        elif argument == "--plain":
            options.output_format = "plain"
        elif argument == "--no-input":
            pass
        elif argument == "--timeout":
            if index + 1 >= len(argv):
                raise ClientError(
                    "E_INVALID_USAGE", "--timeout requires a value", exit_code=2
                )
            index += 1
            try:
                options.timeout_seconds = float(argv[index])
            except ValueError as error:
                raise ClientError(
                    "E_INVALID_USAGE",
                    f"invalid timeout: {argv[index]}",
                    exit_code=2,
                ) from error
        elif argument == "--progress":
            if index + 1 >= len(argv):
                raise ClientError(
                    "E_INVALID_USAGE", "--progress requires a value", exit_code=2
                )
            index += 1
            options.progress = argv[index]
        else:
            raise ClientError(
                "E_INVALID_USAGE", f"unknown option: {argument}", exit_code=2
            )
        index += 1

    if options.target != TARGET:
        raise ClientError(
            "E_INVALID_USAGE", f"target must be {TARGET}", exit_code=2
        )
    if not 0 <= options.log_lines <= MAX_LOG_LINES:
        raise ClientError(
            "E_INVALID_USAGE",
            f"log line count must be between 0 and {MAX_LOG_LINES}",
            exit_code=2,
        )
    if not 1 <= options.timeout_seconds <= 600:
        raise ClientError(
            "E_INVALID_USAGE",
            "timeout must be between 1 and 600 seconds",
            exit_code=2,
        )
    if options.progress not in {"off", "plain"}:
        raise ClientError(
            "E_INVALID_USAGE",
            "progress must be off or plain",
            exit_code=2,
        )
    return options


def run_capture(command: list[str], *, cwd: Path | None = None) -> str:
    completed = subprocess.run(
        command,
        cwd=cwd,
        check=False,
        capture_output=True,
        text=True,
    )
    if completed.returncode != 0:
        raise ClientError(
            "E_SOURCE_CONTRACT",
            f"command failed while inspecting source: {' '.join(command[:3])}",
        )
    return completed.stdout.strip()


def capture_clean_source(
    repo_root: Path, required_branch: str = "main"
) -> SourceSnapshot:
    branch = run_capture(["git", "branch", "--show-current"], cwd=repo_root)
    if branch != required_branch:
        current = branch or "detached"
        raise ClientError(
            "E_SOURCE_CONTRACT",
            f"production deploy requires {required_branch}; current branch is {current}",
        )
    sha = run_capture(
        ["git", "rev-parse", "--verify", "HEAD^{commit}"], cwd=repo_root
    )
    source_status = run_capture(
        ["git", "status", "--porcelain", "--untracked-files=all"], cwd=repo_root
    )
    if source_status:
        raise ClientError(
            "E_SOURCE_CONTRACT",
            f"production deploy requires a clean committed {required_branch} checkout",
        )
    return SourceSnapshot(branch=branch, sha=sha)


def verify_clean_source(repo_root: Path, expected: SourceSnapshot) -> None:
    try:
        current = capture_clean_source(repo_root, expected.branch)
    except ClientError as error:
        raise ClientError(
            "E_SOURCE_CHANGED",
            "source branch or worktree changed during release preparation",
            retryable=True,
        ) from error
    if current.sha != expected.sha:
        raise ClientError(
            "E_SOURCE_CHANGED",
            f"source revision changed during release preparation: expected {expected.sha}, "
            f"found {current.sha}",
            retryable=True,
        )


def read_link_target(link: Path) -> Path | None:
    if not link.is_symlink():
        return None
    raw = Path(os.readlink(link))
    if not raw.is_absolute():
        raw = link.parent / raw
    return raw.resolve(strict=False)


def safe_release_name(link: Path) -> str:
    target = read_link_target(link)
    if target is None:
        return "none"
    name = target.name
    return name if SAFE_NAME.fullmatch(name) else "invalid"


def require_managed_release(
    target: Path | None, paths: RuntimePaths, description: str
) -> Path:
    if target is None or target.parent != paths.releases_dir.resolve(strict=False):
        raise ClientError(
            "E_RELEASE_STATE", f"{description} release is not managed by this service"
        )
    if not (target / "guide/index.html").is_file():
        raise ClientError(
            "E_RELEASE_STATE", f"{description} release is incomplete: {target.name}"
        )
    return target


def replace_link(target: Path, link: Path) -> None:
    temporary = link.with_name(f"{link.name}.next.{os.getpid()}")
    temporary.unlink(missing_ok=True)
    temporary.symlink_to(target)
    os.replace(temporary, link)


def source_label(release: Path | None) -> str:
    if release is None:
        return "none"
    try:
        value = (release / "SOURCE_SHA").read_text(encoding="utf-8").strip()
    except OSError:
        return "unknown"
    return value if SAFE_NAME.fullmatch(value) else "invalid"


def is_launchd_loaded(paths: RuntimePaths) -> bool:
    return (
        subprocess.run(
            ["launchctl", "list", paths.label],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        ).returncode
        == 0
    )


def health_is_ok(
    paths: RuntimePaths,
    *,
    timeout: float = 3.0,
    expected_source: str | None = None,
) -> bool:
    try:
        with urlopen(
            paths.health_url, timeout=timeout
        ) as response:  # noqa: S310 - loopback
            if response.status != 200:
                return False
            payload = json.loads(response.read())
            return (
                isinstance(payload, dict)
                and payload.get("status") == "ok"
                and (
                    expected_source is None
                    or payload.get("source_sha") == expected_source
                )
            )
    except (json.JSONDecodeError, OSError, URLError):
        return False


def wait_for_health(
    paths: RuntimePaths,
    timeout_seconds: float = HEALTH_WAIT_SECONDS,
    expected_source: str | None = None,
) -> bool:
    deadline = time.monotonic() + timeout_seconds
    while time.monotonic() < deadline:
        if health_is_ok(paths, expected_source=expected_source):
            return True
        time.sleep(0.25)
    return False


def status_data(paths: RuntimePaths) -> dict[str, object]:
    current = read_link_target(paths.current_link)
    return {
        "current_release": safe_release_name(paths.current_link),
        "current_source": source_label(current),
        "previous_release": safe_release_name(paths.previous_link),
        "launchd": "loaded" if is_launchd_loaded(paths) else "unavailable",
        "health": "ok" if health_is_ok(paths) else "unavailable",
    }


def sanitize_log_line(line: str) -> str:
    sanitized = "".join(character if character >= " " else " " for character in line)
    sanitized = re.sub(
        r"(?i)(token|secret|password|authorization|api[_-]?key)([=: ]+)([^\s]+)",
        r"\1\2[redacted]",
        sanitized,
    )
    sanitized = re.sub(
        r"(https?://[^\s?]+)\?[^\s]+", r"\1?[redacted]", sanitized
    )
    sanitized = re.sub(r"(\s/[^\s?]*)\?[^\s\"]+", r"\1?[redacted]", sanitized)
    return sanitized[:MAX_LOG_LINE_LENGTH]


def tail_log(path: Path, lines: int) -> list[str]:
    if lines == 0:
        return []
    try:
        content = path.read_text(encoding="utf-8", errors="replace").splitlines()
    except OSError:
        return []
    return [sanitize_log_line(line) for line in content[-lines:]]


def logs_data(paths: RuntimePaths, lines: int) -> dict[str, object]:
    return {
        "requested_lines": lines,
        "stdout": tail_log(paths.stdout_log, lines),
        "stderr": tail_log(paths.stderr_log, lines),
    }


def resolve_python() -> Path:
    executable = Path(sys.executable).resolve()
    if not executable.is_file():
        raise ClientError("E_RUNTIME_MISSING", "Python executable is unavailable")
    return executable


def plist_payload(paths: RuntimePaths, python_bin: Path) -> dict[str, object]:
    runtime_path = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    return {
        "Label": paths.label,
        "ProgramArguments": [
            "/usr/bin/env",
            "-i",
            f"HOME={Path.home()}",
            f"PATH={runtime_path}",
            "PYTHONUNBUFFERED=1",
            str(python_bin),
            str(paths.current_link / "scripts/serve-controller-guide.py"),
            "--port",
            str(PORT),
        ],
        "WorkingDirectory": str(paths.current_link),
        "RunAtLoad": True,
        "KeepAlive": True,
        "ThrottleInterval": 10,
        "StandardOutPath": str(paths.stdout_log),
        "StandardErrorPath": str(paths.stderr_log),
    }


def reload_service(paths: RuntimePaths, python_bin: Path) -> None:
    paths.plist_path.parent.mkdir(parents=True, exist_ok=True)
    paths.log_dir.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        prefix="controller-guide.", suffix=".plist", dir=paths.state_root
    )
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "wb") as handle:
            plistlib.dump(plist_payload(paths, python_bin), handle, sort_keys=True)
        temporary.chmod(0o644)
        os.replace(temporary, paths.plist_path)
    finally:
        temporary.unlink(missing_ok=True)

    subprocess.run(
        ["launchctl", "bootout", f"{paths.domain}/{paths.label}"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    completed = subprocess.run(
        ["launchctl", "bootstrap", paths.domain, str(paths.plist_path)],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )
    if completed.returncode != 0:
        raise ClientError(
            "E_ACTIVATION_FAILED",
            "launchd could not load the controller guide release",
            retryable=True,
        )


def make_read_only(root: Path) -> None:
    for path in sorted(root.rglob("*"), reverse=True):
        path.chmod(0o555 if path.is_dir() else 0o444)
    root.chmod(0o555)


def copy_release_source(
    source_root: Path, destination: Path, source_sha: str
) -> None:
    shutil.copytree(source_root / "guide", destination / "guide")
    (destination / "config").mkdir()
    shutil.copy2(
        source_root / "config/mappings.json",
        destination / "config/mappings.json",
    )
    (destination / "scripts").mkdir()
    shutil.copy2(
        source_root / "scripts/serve-controller-guide.py",
        destination / "scripts/serve-controller-guide.py",
    )
    (destination / "SOURCE_SHA").write_text(f"{source_sha}\n", encoding="utf-8")


def unique_release_path(paths: RuntimePaths, release_id: str) -> Path:
    candidate = paths.releases_dir / release_id
    if not candidate.exists():
        return candidate
    suffix = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    return paths.releases_dir / f"{release_id}-{suffix}"


def bootstrap_legacy_release(paths: RuntimePaths) -> None:
    if paths.current_link.is_symlink():
        return
    required = [
        paths.repo_root / "guide/index.html",
        paths.repo_root / "config/mappings.json",
        paths.repo_root / "scripts/serve-controller-guide.py",
    ]
    if not all(path.is_file() for path in required):
        return
    release_id = (
        "bootstrap-"
        + dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    )
    release = unique_release_path(paths, release_id)
    release.mkdir()
    copy_release_source(paths.repo_root, release, "legacy-repo-root-release")
    make_read_only(release)
    replace_link(release, paths.current_link)


def remove_worktree(repo_root: Path, worktree: Path) -> None:
    if not worktree.exists():
        return
    subprocess.run(
        ["git", "worktree", "remove", "--force", str(worktree)],
        cwd=repo_root,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )


def progress(message: str, mode: str) -> None:
    if mode == "plain":
        print(f"[deploy-controller-guide] {message}", file=sys.stderr)


def prepare_release(
    paths: RuntimePaths, snapshot: SourceSnapshot, progress_mode: str
) -> Path:
    paths.releases_dir.mkdir(parents=True, exist_ok=True)
    (paths.repo_root / "tmp").mkdir(exist_ok=True)
    worktree = Path(
        tempfile.mkdtemp(
            prefix="controller-guide-build.", dir=paths.repo_root / "tmp"
        )
    )
    worktree.rmdir()
    temporary_release: Path | None = None
    try:
        subprocess.run(
            [
                "git",
                "worktree",
                "add",
                "--quiet",
                "--detach",
                str(worktree),
                snapshot.sha,
            ],
            cwd=paths.repo_root,
            check=True,
        )
        verify_clean_source(paths.repo_root, snapshot)
        progress("running exact-source full gate", progress_mode)
        check_output = sys.stderr if progress_mode == "plain" else subprocess.DEVNULL
        completed = subprocess.run(
            [str(worktree / "scripts/check-controller-guide-full.sh")],
            cwd=worktree,
            stdout=check_output,
            stderr=check_output,
            check=False,
        )
        if completed.returncode != 0:
            raise ClientError("E_CHECK_FAILED", "full release gate failed")
        verify_clean_source(paths.repo_root, snapshot)

        temporary_release = Path(
            tempfile.mkdtemp(
                prefix=f".{snapshot.sha[:12]}.", dir=paths.releases_dir
            )
        )
        copy_release_source(worktree, temporary_release, snapshot.sha)
        verify_clean_source(paths.repo_root, snapshot)
        remove_worktree(paths.repo_root, worktree)
        verify_clean_source(paths.repo_root, snapshot)

        release = unique_release_path(paths, snapshot.sha[:12])
        make_read_only(temporary_release)
        os.replace(temporary_release, release)
        temporary_release = None
        return release
    except subprocess.CalledProcessError as error:
        raise ClientError(
            "E_SOURCE_SNAPSHOT", "could not create the exact-source build worktree"
        ) from error
    finally:
        remove_worktree(paths.repo_root, worktree)
        if temporary_release is not None and temporary_release.exists():
            shutil.rmtree(temporary_release, ignore_errors=True)


def restore_release(
    paths: RuntimePaths,
    old_target: Path | None,
    python_bin: Path,
    timeout_seconds: float,
) -> None:
    if old_target is None or not old_target.is_dir():
        subprocess.run(
            ["launchctl", "bootout", f"{paths.domain}/{paths.label}"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
        return
    replace_link(old_target, paths.current_link)
    try:
        reload_service(paths, python_bin)
        wait_for_health(
            paths,
            timeout_seconds,
            expected_source=source_label(old_target),
        )
    except ClientError:
        pass


def apply_release(paths: RuntimePaths, options: Options) -> dict[str, object]:
    snapshot = capture_clean_source(paths.repo_root)
    progress(
        f"source={snapshot.sha} branch={snapshot.branch}",
        options.progress,
    )
    python_bin = resolve_python()
    release = prepare_release(paths, snapshot, options.progress)
    bootstrap_legacy_release(paths)
    old_target = read_link_target(paths.current_link)
    old_previous = read_link_target(paths.previous_link)
    if old_target is not None:
        require_managed_release(old_target, paths, "current")

    try:
        # This is the final source check before any live pointer or process changes.
        verify_clean_source(paths.repo_root, snapshot)
        if old_target is not None:
            replace_link(old_target, paths.previous_link)
        replace_link(release, paths.current_link)
        progress("activating versioned release", options.progress)
        reload_service(paths, python_bin)
        if not wait_for_health(
            paths,
            options.timeout_seconds,
            expected_source=snapshot.sha,
        ):
            raise ClientError(
                "E_HEALTH_TIMEOUT",
                "new release failed local health; previous release was restored when available",
                exit_code=5,
                retryable=True,
            )
    except ClientError:
        restore_release(paths, old_target, python_bin, options.timeout_seconds)
        if old_previous is None:
            paths.previous_link.unlink(missing_ok=True)
        else:
            replace_link(old_previous, paths.previous_link)
        raise
    except OSError as error:
        restore_release(paths, old_target, python_bin, options.timeout_seconds)
        if old_previous is None:
            paths.previous_link.unlink(missing_ok=True)
        else:
            replace_link(old_previous, paths.previous_link)
        raise ClientError(
            "E_ACTIVATION_FAILED",
            "release activation failed; previous release was restored when available",
            retryable=True,
        ) from error
    except KeyboardInterrupt as error:
        restore_release(paths, old_target, python_bin, options.timeout_seconds)
        if old_previous is None:
            paths.previous_link.unlink(missing_ok=True)
        else:
            replace_link(old_previous, paths.previous_link)
        raise ClientError(
            "E_INTERRUPTED",
            "deployment interrupted; previous release was restored when available",
            exit_code=5,
            retryable=True,
        ) from error

    return {
        "release": release.name,
        "source_sha": snapshot.sha,
        "previous_release": (
            old_target.name if old_target is not None else "none"
        ),
        **status_data(paths),
    }


def rollback_release(
    paths: RuntimePaths, options: Options
) -> dict[str, object]:
    python_bin = resolve_python()
    current = require_managed_release(
        read_link_target(paths.current_link), paths, "current"
    )
    previous = require_managed_release(
        read_link_target(paths.previous_link), paths, "previous"
    )
    try:
        replace_link(previous, paths.current_link)
        replace_link(current, paths.previous_link)
        reload_service(paths, python_bin)
        if not wait_for_health(
            paths,
            options.timeout_seconds,
            expected_source=source_label(previous),
        ):
            raise ClientError(
                "E_ROLLBACK_HEALTH",
                "rollback release failed local health",
                exit_code=6,
            )
    except (ClientError, KeyboardInterrupt, OSError) as error:
        replace_link(current, paths.current_link)
        replace_link(previous, paths.previous_link)
        restore_release(paths, current, python_bin, options.timeout_seconds)
        reason = (
            error.message
            if isinstance(error, ClientError)
            else (
                "rollback was interrupted"
                if isinstance(error, KeyboardInterrupt)
                else "rollback activation failed"
            )
        )
        raise ClientError(
            "E_ROLLBACK_FAILED",
            f"rollback failed and the original release was restored: {reason}",
            exit_code=6,
        ) from error
    return status_data(paths)


def uninstall(paths: RuntimePaths) -> dict[str, object]:
    subprocess.run(
        ["launchctl", "bootout", f"{paths.domain}/{paths.label}"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    paths.plist_path.unlink(missing_ok=True)
    return {"launchd": "unavailable", "releases_retained": True}


def base_data(options: Options, paths: RuntimePaths) -> dict[str, object]:
    return {
        "action": options.action,
        "mode": options.action,
        "service": SERVICE,
        "target": TARGET,
        "local_url": paths.health_url,
        "public_url": PUBLIC_URL,
        "launchd_label": paths.label,
        "timeout_seconds": options.timeout_seconds,
    }


def emit_result(
    *,
    options: Options,
    paths: RuntimePaths,
    started: float,
    request_id: str,
    data: dict[str, object] | None = None,
    error: ClientError | None = None,
) -> None:
    result_data = {**base_data(options, paths), **(data or {})}
    status = "error" if error else "ok"
    if options.output_format == "plain":
        fields = [
            f"status={status}",
            f"action={options.action}",
            f"service={SERVICE}",
            f"target={TARGET}",
        ]
        for key in (
            "release",
            "source_sha",
            "current_release",
            "previous_release",
            "launchd",
            "health",
        ):
            if key in result_data:
                fields.append(f"{key}={result_data[key]}")
        if error:
            fields.extend((f"code={error.code}", f"message={error.message}"))
        print(" ".join(fields))
        if options.action == "logs" and data:
            for stream in ("stdout", "stderr"):
                for line in data.get(stream, []):
                    print(f"[{stream}] {line}")
        return

    payload = {
        "schema_version": SCHEMA_VERSION,
        "command": COMMAND,
        "status": status,
        "data": result_data,
        "error": None
        if error is None
        else {
            "code": error.code,
            "message": error.message,
            "retryable": error.retryable,
            "hint": {
                "E_INVALID_USAGE": "Run deploy-controller-guide.sh --help.",
                "E_SOURCE_CONTRACT": "Commit or discard local changes and use main.",
                "E_SOURCE_CHANGED": "Retry; the latest desired revision should supersede this run.",
                "E_CHECK_FAILED": (
                    "Run scripts/check-controller-guide-full.sh and fix the reported failure."
                ),
                "E_SOURCE_SNAPSHOT": "Inspect Git worktrees, then retry from clean main.",
                "E_RELEASE_STATE": "Inspect --status; repair managed release links before retrying.",
                "E_RUNTIME_MISSING": "Install or select a working local Python 3 runtime.",
                "E_ACTIVATION_FAILED": "Inspect --status and --logs, then retry or use --rollback.",
                "E_HEALTH_TIMEOUT": "Inspect --status and --logs, then retry or use --rollback.",
                "E_INTERRUPTED": "Retry; recovery was attempted before exit.",
                "E_ROLLBACK_HEALTH": "Inspect --status and --logs before another rollback.",
                "E_ROLLBACK_FAILED": "Inspect --status and --logs; the original release was restored.",
                "E_OPERATION_FAILED": "Inspect status and sanitized logs, then retry.",
            }.get(error.code),
        },
        "meta": {
            "request_id": request_id,
            "duration_ms": int((time.monotonic() - started) * 1000),
            "timestamp_utc": (
                dt.datetime.now(dt.timezone.utc)
                .isoformat()
                .replace("+00:00", "Z")
            ),
        },
    }
    print(json.dumps(payload, separators=(",", ":"), sort_keys=True))


def fail_before_options(
    error: ClientError, argv: list[str], started: float, request_id: str
) -> NoReturn:
    output_format = (
        "plain" if "--plain" in argv and "--json" not in argv else "json"
    )
    options = Options(output_format=output_format)
    paths = default_paths(Path(__file__).resolve().parents[1])
    emit_result(
        options=options,
        paths=paths,
        started=started,
        request_id=request_id,
        error=error,
    )
    raise SystemExit(error.exit_code)


def main(argv: list[str] | None = None) -> int:
    arguments = list(sys.argv[1:] if argv is None else argv)
    started = time.monotonic()
    request_id = str(uuid.uuid4())
    try:
        options = parse_args(arguments)
    except ClientError as error:
        fail_before_options(error, arguments, started, request_id)
    if options is None:
        return 0

    paths = default_paths(Path(__file__).resolve().parents[1])
    try:
        if options.action == "dry-run":
            data = {
                "source_contract": "clean-main-exact-sha",
                "release_root": str(paths.release_root),
                "activation": "versioned-health-gated",
            }
        elif options.action == "status":
            data = status_data(paths)
        elif options.action == "logs":
            data = logs_data(paths, options.log_lines)
        elif options.action == "apply":
            data = apply_release(paths, options)
        elif options.action == "rollback":
            data = rollback_release(paths, options)
        elif options.action == "uninstall":
            data = uninstall(paths)
        else:  # pragma: no cover - parse_args owns the action set
            raise ClientError(
                "E_INVALID_USAGE",
                f"unsupported action: {options.action}",
                exit_code=2,
            )
    except KeyboardInterrupt:
        error = ClientError(
            "E_INTERRUPTED",
            "operation interrupted before completion",
            exit_code=5,
            retryable=True,
        )
        emit_result(
            options=options,
            paths=paths,
            started=started,
            request_id=request_id,
            error=error,
        )
        return error.exit_code
    except (OSError, subprocess.SubprocessError):
        error = ClientError(
            "E_OPERATION_FAILED",
            "local production operation failed",
            retryable=True,
        )
        emit_result(
            options=options,
            paths=paths,
            started=started,
            request_id=request_id,
            error=error,
        )
        return error.exit_code
    except ClientError as error:
        emit_result(
            options=options,
            paths=paths,
            started=started,
            request_id=request_id,
            error=error,
        )
        return error.exit_code

    emit_result(
        options=options,
        paths=paths,
        started=started,
        request_id=request_id,
        data=data,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
