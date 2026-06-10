# RunPod Worker for stable-diffusion.cpp

**Repository:** https://github.com/ddr-runpod/worker-sdcpp

## Overview

A RunPod serverless worker using [stable-diffusion.cpp](https://github.com/leejet/stable-diffusion.cpp) for high-performance diffusion model inference. Runs as either a queue-based endpoint (RunPod SDK handler) or a load-balancing endpoint (FastAPI reverse proxy to the A1111-compatible REST API).

## Architecture

The worker runs in a RunPod container with two main components:

1. **Python Handler** (`runpod.serverless` or FastAPI, selected by `ENDPOINT_MODE`): Receives jobs from the RunPod endpoint and proxies requests to the sd-server backend. In `queue` mode (default) it uses the `runpod` SDK handler. In `loadbalancer` mode it runs a FastAPI app that serves `/ping` and reverse-proxies every other path to sd-server.

2. **sd-server** (`stable-diffusion.cpp`): Serves an A1111-compatible REST API on port 8080. The model is loaded once at startup from a network volume and processes requests sequentially with mutex protection.

Request flow:

- `queue` mode: RunPod Queue → RunPod Internal Network → runpod SDK handler → sd-server
- `loadbalancer` mode: RunPod Load Balancer → FastAPI on `$PORT` → sd-server on `127.0.0.1:8080`

### Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| Two endpoint modes (`queue` + `loadbalancer`) | One image serves both RunPod serverless endpoint types; `ENDPOINT_MODE` selects the worker entrypoint at deploy time |
| sd-server backend | Model stays loaded in memory for fast subsequent requests |
| One worker per model | sd-server does not support runtime model switching |
| Network volume for models | Avoids committing to specific models; allows model updates without redeployment |
| A1111-compatible API | Wide tool compatibility (ComfyUI, InvokeAI, etc.) |
| CUDA only | Simplifies build; NVIDIA GPUs are standard on RunPod |

## Technologies

| Component | Technology | Notes |
|-----------|------------|-------|
| Inference Engine | [stable-diffusion.cpp](https://github.com/leejet/stable-diffusion.cpp) | Pure C/C++, ggml-based |
| Server Component | `sd-server` (from stable-diffusion.cpp) | HTTP API server |
| Handler SDK | [runpod-python](https://github.com/runpod/runpod-python) v1.8.2+ | Queue job processing with progress updates |
| GPU Backend | CUDA (CUBLAS) | Primary target |
| Container Base | `nvidia/cuda:12.6.3-cudnn-devel-ubuntu24.04` | Multi-stage build |

## Build Configuration

| Flag | Value | Rationale |
|------|-------|------------|
| `-DSD_SERVER_BUILD_FRONTEND` | `OFF` | Frontend is not needed for serverless worker; reduces build time and binary size |

### Build Arguments

| Argument | Default | Description |
|----------|---------|-------------|
| `SD_CPP_COMMIT` | `7397dda` | Git commit hash of stable-diffusion.cpp for reproducible builds |

Example:
```bash
docker build --build-arg SD_CPP_COMMIT=7397dda -t worker-sdcpp:latest .
```

## Code Conventions

- Make sure the code documents itself as in the Clean Code principles and comment it at the places where the intent would otherwise be unclear.

## Tests

The project has a `pytest` suite under `tests/`. Tests are local-only: no GPU, no live sd-server, no RunPod CI integration. RunPod's build pipeline does not invoke `pytest`; tests are run on a developer machine before pushing.

### How to run

```bash
# Install runtime + test dependencies (once):
uv pip install -r requirements.txt -r requirements-dev.txt

# Run the full suite:
pytest

# Run only the unit tests (skip integration):
pytest tests/ --ignore=tests/integration

# Run a single test by name:
pytest -k test_ping_returns_204_when_upstream_unreachable
```

### Layout

```
tests/
├── conftest.py                             # Shared fixtures: respx_mock, client, env setup
├── test_handler_load_balancing.py          # FastAPI proxy + /ping (respx-driven, 14 tests)
├── test_handler_queue.py                   # runpod SDK handler (requests-mock, 7 tests)
└── integration/
    ├── conftest.py                         # Spawns a real local HTTP upstream server
    └── test_proxy_e2e.py                   # End-to-end tests against real sockets (4 tests)
```

### Test-only dependencies

`requirements-dev.txt` (pytest, pytest-asyncio, respx, requests-mock) is **not** installed in the production Docker image and the Dockerfile is unchanged. RunPod's CI does not pick it up; install it locally before running `pytest`.

### Gotcha: env-var-driven module config

`src/handler_load_balancing.py` reads `SD_SERVER_URL` at **import time** (line 10) and binds the FastAPI lifespan's `httpx.AsyncClient` to that URL. The test fixtures work around this by removing the module from `sys.modules` and re-importing it whenever the env var changes between tests (see `tests/conftest.py:_reload_handler_module` and `tests/integration/conftest.py:upstream_app`). When adding a new fixture that needs a different `SD_SERVER_URL`, do the same dance.

## Environment Variables

All static server parameters configured via ENV vars at container startup.
See [docs/env.md](docs/env.md) for complete reference.

## API Endpoints

The sd-server exposes A1111-compatible and OpenAI-compatible REST APIs.
See [docs/stable-diffusion.cpp/api.md](docs/stable-diffusion.cpp/api.md) for complete reference.

## Known Limitations

| Limitation | Description | Workaround |
|------------|-------------|------------|
| No runtime model switching | Model loaded once at startup | Deploy multiple workers |
| No progress endpoint | `/sdapi/v1/progress` not implemented | Client waits for response |
| No interrupt/skip | Cannot cancel generation | Wait for completion |
| Sequential processing | One generation at a time | Increase concurrent workers |

## Documentation

| Document | Description |
|----------|-------------|
| `docs/env.md` | Environment variable reference |
| `docs/stable-diffusion.cpp/server-parameters.md` | Complete reference for all sd-server CLI parameters |
| `docs/stable-diffusion.cpp/api.md` | REST API reference for all endpoints |

## Project Structure

```
worker-sdcpp/
├── scripts/
│   └── startup.sh                       # Entry point: launches sd-server then the selected handler
├── src/
│   ├── handler_queue.py                 # runpod.serverless SDK handler (queue mode, default)
│   └── handler_load_balancing.py        # FastAPI reverse proxy + /ping (loadbalancer mode)
├── tests/
│   ├── conftest.py                      # Shared fixtures
│   ├── test_handler_load_balancing.py   # 14 respx-driven tests
│   ├── test_handler_queue.py            # 7 requests-mock tests
│   └── integration/
│       ├── conftest.py                  # Real local HTTP upstream fixture
│       └── test_proxy_e2e.py            # 4 end-to-end tests against real sockets
├── docs/
│   ├── env.md                           # Environment variable reference
│   └── stable-diffusion.cpp/
│       ├── server-parameters.md         # CLI parameter reference
│       └── api.md                       # API endpoint reference
├── Dockerfile                           # Multi-stage CUDA build
├── requirements.txt                     # Python dependencies (runpod, fastapi, uvicorn, httpx)
├── requirements-dev.txt                 # Test-only dependencies (pytest, respx, requests-mock)
├── pyproject.toml                       # pytest config (asyncio_mode = "auto")
├── AGENTS.md                            # This file (LLM overview)
└── README.md                            # User documentation
```

## References

- [stable-diffusion.cpp](https://github.com/leejet/stable-diffusion.cpp)
- [stable-diffusion-cpp-python](https://github.com/william-murray1204/stable-diffusion-cpp-python)
- [Runpod Documentation Overview](https://docs.runpod.io/llms.txt)
- [RunPod Serverless](https://docs.runpod.io/serverless)
- [A1111 API](https://github.com/AUTOMATIC1111/stable-diffusion-webui/wiki/API)
