#!/usr/bin/env python3
"""Serve the controller guide and live mappings on the loopback interface."""

from __future__ import annotations

import argparse
import json
import mimetypes
import sys
import threading
import webbrowser
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit


REPO_ROOT = Path(__file__).resolve().parents[1]
GUIDE_ROOT = REPO_ROOT / "guide"
MAPPINGS_PATH = REPO_ROOT / "config" / "mappings.json"
STATIC_ROUTES = {
    "/": "index.html",
    "/index.html": "index.html",
    "/boot.js": "boot.js",
    "/styles.css": "styles.css",
    "/app.js": "app.js",
}


class ControllerGuideHandler(BaseHTTPRequestHandler):
    server_version = "ControllerGuide/1.0"

    def do_HEAD(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler contract
        self._serve(send_body=False)

    def do_GET(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler contract
        self._serve(send_body=True)

    def _serve(self, *, send_body: bool) -> None:
        path = urlsplit(self.path).path

        if path == "/api/health":
            self._send_json(
                {"status": "ok", "config": str(MAPPINGS_PATH.relative_to(REPO_ROOT))},
                send_body=send_body,
            )
            return

        if path == "/api/mappings":
            try:
                payload = json.loads(MAPPINGS_PATH.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError) as error:
                self._send_json(
                    {"error": "Unable to load config/mappings.json", "detail": str(error)},
                    status=HTTPStatus.INTERNAL_SERVER_ERROR,
                    send_body=send_body,
                )
                return

            self._send_json(payload, send_body=send_body)
            return

        filename = STATIC_ROUTES.get(path)
        if filename is None:
            self._send_json(
                {"error": "Not found"},
                status=HTTPStatus.NOT_FOUND,
                send_body=send_body,
            )
            return

        asset_path = GUIDE_ROOT / filename
        try:
            body = asset_path.read_bytes()
        except OSError as error:
            self._send_json(
                {"error": f"Unable to load {filename}", "detail": str(error)},
                status=HTTPStatus.INTERNAL_SERVER_ERROR,
                send_body=send_body,
            )
            return

        content_type = mimetypes.guess_type(asset_path.name)[0] or "application/octet-stream"
        if content_type.startswith("text/") or content_type == "application/javascript":
            content_type = f"{content_type}; charset=utf-8"
        self._send(body, content_type=content_type, send_body=send_body)

    def _send_json(
        self,
        payload: object,
        *,
        status: HTTPStatus = HTTPStatus.OK,
        send_body: bool,
    ) -> None:
        body = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        self._send(
            body,
            status=status,
            content_type="application/json; charset=utf-8",
            send_body=send_body,
        )

    def _send(
        self,
        body: bytes,
        *,
        content_type: str,
        send_body: bool,
        status: HTTPStatus = HTTPStatus.OK,
    ) -> None:
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Referrer-Policy", "no-referrer")
        self.send_header("X-Frame-Options", "DENY")
        self.send_header(
            "Content-Security-Policy",
            "default-src 'self'; script-src 'self'; style-src 'self'; "
            "img-src 'self' data:; connect-src 'self'; object-src 'none'; "
            "base-uri 'none'; frame-ancestors 'none'",
        )
        self.end_headers()
        if send_body:
            self.wfile.write(body)

    def log_message(self, format_string: str, *args: object) -> None:
        print(f"[guide] {self.address_string()} {format_string % args}")


def create_server(host: str = "127.0.0.1", port: int = 8173) -> ThreadingHTTPServer:
    return ThreadingHTTPServer((host, port), ControllerGuideHandler)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", default=8173, type=int, help="Bind port (default: 8173)")
    parser.add_argument("--open", action="store_true", help="Open the guide in the default browser")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        server = create_server("127.0.0.1", args.port)
    except OSError as error:
        print(f"Unable to start controller guide: {error}", file=sys.stderr)
        return 1

    _, port = server.server_address[:2]
    url = f"http://localhost:{port}/"
    print(f"Controller Guide: {url}", flush=True)
    print("Press Control-C to stop.", flush=True)

    if args.open:
        threading.Timer(0.15, lambda: webbrowser.open(url)).start()

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping Controller Guide.")
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
