import http.server
import json
import os
import socket
import socketserver
import sys
import threading

import pytest


class _UpstreamHandler(http.server.BaseHTTPRequestHandler):
    """Minimal HTTP server that echoes path, method, and (for POST) body.

    Used by the integration tests to exercise the real FastAPI proxy
    end-to-end against an actual TCP socket, catching issues respx would
    miss (URL encoding, body framing, etc.).
    """

    def _respond(self, body):
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/sdapi/v1/sd-models":
            self._respond(b'[{"title": "integration-mock"}]')
        else:
            body = json.dumps(
                {"echo_path": self.path, "echo_method": "GET"}
            ).encode()
            self._respond(body)

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        req_body = self.rfile.read(length) if length else b""
        body = json.dumps(
            {
                "echo_path": self.path,
                "echo_method": "POST",
                "echo_body": req_body.decode("utf-8", errors="replace"),
            }
        ).encode()
        self._respond(body)

    def log_message(self, *args, **kwargs):
        # Silence the per-request access log so test output stays clean.
        pass


def _free_port():
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


@pytest.fixture
def upstream_app():
    """Spawn a real local HTTP server and reload the handler module so
    its SD_SERVER_URL points at it. Yields ``(base_url, app)``.

    Reloading the module is the only way to make ``SD_SERVER_URL`` take
    effect, because the handler reads it at import time. The original
    env var and module state are restored on teardown.
    """
    port = _free_port()
    socketserver.TCPServer.allow_reuse_address = True
    server = socketserver.ThreadingTCPServer(
        ("127.0.0.1", port), _UpstreamHandler
    )
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()

    original_url = os.environ.get("SD_SERVER_URL")
    os.environ["SD_SERVER_URL"] = f"http://127.0.0.1:{port}"

    for name in list(sys.modules):
        if name == "src.handler_load_balancing" or name.startswith(
            "src.handler_load_balancing."
        ):
            del sys.modules[name]
    import src.handler_load_balancing

    yield f"http://127.0.0.1:{port}", src.handler_load_balancing.app

    server.shutdown()
    server.server_close()

    if original_url is None:
        os.environ.pop("SD_SERVER_URL", None)
    else:
        os.environ["SD_SERVER_URL"] = original_url

    # Re-import once more so subsequent tests see the original env var.
    for name in list(sys.modules):
        if name == "src.handler_load_balancing" or name.startswith(
            "src.handler_load_balancing."
        ):
            del sys.modules[name]
    import src.handler_load_balancing  # noqa: F401


@pytest.fixture
def integration_client(upstream_app):
    from fastapi.testclient import TestClient

    _, app = upstream_app
    with TestClient(app) as client:
        yield client
