import importlib
import os
import sys

# Set default env vars BEFORE the handler module is imported. The handler
# reads SD_SERVER_URL and HANDLER_TIMEOUT at module import time, so the
# values need to be in place before any test (or fixture) imports it.
os.environ.setdefault("SD_SERVER_URL", "http://mock-upstream")
os.environ.setdefault("HANDLER_TIMEOUT", "5")
# Mute the runpod SDK's progress/job-completion logs that pollute test
# output. The SDK reads RUNPOD_LOG_LEVEL at import time and only emits
# messages at or above that level; "ERROR" suppresses the noisy DEBUG
# progress updates and the harmless "Failed to return job results"
# error that fires when no JOB_DONE_URL is configured.
os.environ.setdefault("RUNPOD_LOG_LEVEL", "NOTSET")

import pytest
import respx


def _reload_handler_module():
    """Force a fresh import of src.handler_load_balancing.

    The handler module captures SD_SERVER_URL at import time, so tests
    that change the env var (e.g. the integration test pointing it at a
    real local server) need the module re-read. Removing the cached
    module from sys.modules and re-importing is the standard way to do
    this without touching the source.
    """
    for name in list(sys.modules):
        if name == "src.handler_load_balancing" or name.startswith(
            "src.handler_load_balancing."
        ):
            del sys.modules[name]
    import src.handler_load_balancing

    return src.handler_load_balancing


@pytest.fixture
def handler_module():
    """Freshly imported handler module with the current env vars."""
    return _reload_handler_module()


@pytest.fixture
def respx_mock():
    """Activate respx mocking for the duration of a test.

    All calls made through any httpx client during the test are
    intercepted; routes must be registered explicitly on the yielded
    ``mock`` object (or via the ``@respx.mock`` decorator).
    """
    with respx.mock(assert_all_called=False) as mock:
        yield mock


@pytest.fixture
def client(handler_module):
    """FastAPI TestClient with the lifespan enabled.

    Entering the context manager runs the handler's lifespan, which
    creates the shared ``httpx.AsyncClient`` on ``app.state.client``.
    Exiting the context closes it.
    """
    from fastapi.testclient import TestClient

    with TestClient(handler_module.app) as c:
        yield c
