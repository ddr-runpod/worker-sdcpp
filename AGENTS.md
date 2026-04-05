# RunPod Worker for stable-diffusion.cpp

**Repository:** https://github.com/ddr-runpod/worker-sdcpp

## Overview

A RunPod serverless worker using [stable-diffusion.cpp](https://github.com/leejet/stable-diffusion.cpp) for high-performance diffusion model inference. Uses the RunPod SDK to process queue-based jobs.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  RunPod Container                                                │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  Python Handler (runpod.serverless)                     │    │
│  │  - Receives jobs from RunPod queue                       │    │
│  │  - Proxies requests to sd-server                         │    │
│  └─────────────────────────────────────────────────────────┘    │
│                              ▲                                   │
│                              │                                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  sd-server (stable-diffusion.cpp)                       │    │
│  │  - Model loaded once at startup (from network volume)   │    │
│  │  - A1111-compatible REST API on port 8080              │    │
│  │  - Sequential request processing (mutex-protected)      │    │
│  └─────────────────────────────────────────────────────────┘    │
│                              ▲                                   │
│                              │                                   │
│                     RunPod Internal Network                      │
│                              │                                   │
│         ┌─────────────────────┴─────────────────────┐          │
│         │         RunPod Serverless Endpoint         │          │
│         │   (queues requests → worker container)     │          │
│         └───────────────────────────────────────────┘          │
└─────────────────────────────────────────────────────────────────┘
```

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
| Handler SDK | [runpod-python](https://github.com/runpod/runpod-python) | Queue job processing |
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


## Supported Models

| Model Family | Status | Formats |
|--------------|--------|---------|
| SD 1.x, SD 2.x, SDXL | ✅ Supported | safetensors, GGUF |
| SD-Turbo, SDXL-Turbo | ✅ Supported | safetensors, GGUF |
| SD3/SD3.5 | ⚙️ To verify | Requires clip_l, clip_g, t5xxl |
| FLUX.1, FLUX.2 | ⚙️ To verify | Requires additional encoders |
| LoRA Support | ✅ Supported | Hot-reload via API |

## Environment Variables

All static server parameters configured via ENV vars at container startup.
See [docs/env.md](docs/env.md) for complete reference.

## Job Input Format

Jobs submitted to RunPod queue should have this structure:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `mode` | string | `"txt2img"` | Generation mode: `"txt2img"` or `"img2img"` |
| `prompt` | string | - | Positive prompt (required) |
| `negative_prompt` | string | `""` | Negative prompt |
| `width` | int | `512` | Image width |
| `height` | int | `512` | Image height |
| `steps` | int | `20` | Sampling steps |
| `cfg_scale` | float | `7.0` | CFG scale |
| `seed` | int | `-1` | Random seed |
| `sampler_name` | string | `"euler_a"` | Sampler name |
| `scheduler` | string | `"default"` | Scheduler name |

For `img2img` mode:

| Parameter | Type | Description |
|-----------|------|-------------|
| `init_images` | array | List of base64-encoded images |
| `denoising_strength` | float | Denoising strength |
| `mask` | string | Optional base64-encoded mask |
| `extra_images` | array | Optional list of base64-encoded reference images |

## API Endpoints

### A1111-Compatible

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/sdapi/v1/txt2img` | POST | Text-to-image |
| `/sdapi/v1/img2img` | POST | Image-to-image with mask |
| `/sdapi/v1/loras` | GET | List LoRA models |
| `/sdapi/v1/refresh-loras` | POST | Refresh LoRA cache |
| `/sdapi/v1/samplers` | GET | List samplers |
| `/sdapi/v1/schedulers` | GET | List schedulers |
| `/sdapi/v1/sd-models` | GET | Get current model info |
| `/sdapi/v1/options` | GET | Get options |

### OpenAI-Compatible

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/v1/models` | GET | List models |
| `/v1/images/generations` | POST | Text-to-image |
| `/v1/images/edits` | POST | Image editing/inpainting |

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
│   ├── __init__.py         # Exports handler, healthcheck
│   ├── handler.py          # RunPod handler function (runpod.serverless)
│   └── healthcheck.py      # Server health check utilities
├── tests/                  # Test scripts
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
