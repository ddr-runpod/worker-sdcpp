# RunPod Worker for stable-diffusion.cpp

**Repository:** https://github.com/ddr-runpod/worker-sdcpp

## Overview

A RunPod serverless worker using [stable-diffusion.cpp](https://github.com/leejet/stable-diffusion.cpp) for high-performance diffusion model inference. Uses the RunPod SDK to process queue-based jobs.

## Architecture

The worker runs in a RunPod container with two main components:

1. **Python Handler** (`runpod.serverless`): Receives jobs from the RunPod queue and proxies requests to the sd-server backend.

2. **sd-server** (`stable-diffusion.cpp`): Serves an A1111-compatible REST API on port 8080. The model is loaded once at startup from a network volume and processes requests sequentially with mutex protection.

Request flow: RunPod Serverless Endpoint → RunPod Internal Network → sd-server → Python Handler

### Key Design Decisions

| Decision | Rationale |
|----------|-----------|
| RunPod SDK handler | Required for queue-based serverless endpoints |
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
│   └── startup.sh          # Entry point: launches sd-server then handler
├── src/
│   ├── __init__.py         # Exports handler
│   └── handler.py          # RunPod handler function (runpod.serverless)
├── docs/
│   ├── env.md              # Environment variable reference
│   └── stable-diffusion.cpp/
│       ├── server-parameters.md  # CLI parameter reference
│       └── api.md               # API endpoint reference
├── Dockerfile              # Multi-stage CUDA build
├── requirements.txt        # Python dependencies (includes runpod)
├── AGENTS.md               # This file (LLM overview)
└── README.md               # User documentation
```

## References

- [stable-diffusion.cpp](https://github.com/leejet/stable-diffusion.cpp)
- [stable-diffusion-cpp-python](https://github.com/william-murray1204/stable-diffusion-cpp-python)
- [Runpod Documentation Overview](https://docs.runpod.io/llms.txt)
- [RunPod Serverless](https://docs.runpod.io/serverless)
- [A1111 API](https://github.com/AUTOMATIC1111/stable-diffusion-webui/wiki/API)
