# Environment Variable Reference

This file documents all environment variables used to configure the stable-diffusion.cpp server.

## Server Configuration

| Env Variable | CLI Arg | Description | Default |
|--------------|---------|-------------|---------|
| `SD_SERVER_HOST` | `--listen-ip` | IP address to bind to | `0.0.0.0` |
| `SD_SERVER_PORT` | `--listen-port` | Port to listen on | `8080` |
| `SD_VERBOSE` | `--verbose` | Enable verbose debug logging | `false` |

## Model Loading

| Env Variable | CLI Arg | Description |
|--------------|---------|-------------|
| `SD_MODEL_PATH` | `--model` | Path to main model file |
| `SD_DIFFUSION_MODEL_PATH` | `--diffusion-model` | Standalone diffusion model |
| `SD_CLIP_L_PATH` | `--clip_l` | CLIP-L text encoder (SDXL/SD3/FLUX) |
| `SD_CLIP_G_PATH` | `--clip_g` | CLIP-G text encoder (SD3) |
| `SD_T5XXL_PATH` | `--t5xxl` | T5XXL encoder (FLUX/SD3) |
| `SD_LLM_PATH` | `--llm` | LLM encoder (FLUX.2, Qwen-Image) |
| `SD_VAE_PATH` | `--vae` | Standalone VAE model |
| `SD_AUDIO_VAE_PATH` | `--audio-vae` | Standalone LTX audio VAE model |
| `SD_LORA_DIR` | `--lora-model-dir` | Directory containing LoRA models. Defaults to `/media/loras/`. |
| `HF_LORAS` | (none) | Comma-separated list of Hugging Face URLs in `org/repo/file` format. Each file is downloaded to `SD_LORA_DIR` at startup via `hf download` (uses `HF_TOKEN` for gated repos). Composes with `RC_LORA_URL`, `RC_LORA_S3_BUCKET`, and `RP_LORA_DIR`. |
| `RC_LORA_URL` | (none) | HTTP URL to download LoRA files from at startup via `rclone copy :http:`. Takes precedence over `SD_LORA_DIR` and `RP_LORA_DIR`. |
| `RC_LORA_S3_BUCKET` | (none) | S3 bucket and optional prefix for LoRA downloads via `rclone copy :s3:` (e.g. `my-bucket/loras/`). Requires `RC_LORA_S3_ENDPOINT`, `RC_LORA_S3_ACCESS_KEY_ID`, and `RC_LORA_S3_SECRET_ACCESS_KEY`. Takes precedence over `SD_LORA_DIR` and `RP_LORA_DIR`. |
| `RC_LORA_S3_ENDPOINT` | (none) | S3-compatible endpoint URL (e.g. `https://s3api-us-ks-2.runpod.io/`). |
| `RC_LORA_S3_ACCESS_KEY_ID` | (none) | S3 access key ID. |
| `RC_LORA_S3_SECRET_ACCESS_KEY` | (none) | S3 secret access key. |
| `RC_LORA_S3_REGION` | `us-east-1` | S3 region. |
| `RC_LORA_S3_PROVIDER` | `Other` | rclone `--s3-provider` value. Default `Other` works with RunPod's S3-compatible API; set to `AWS`, `Minio`, `Cloudflare`, `Wasabi`, etc. for other backends. |
| `RC_TRANSFERS` | `5` | Number of parallel file transfers for rclone operations. |
| `SD_TYPE` | `--type` | Quantization type (f32, f16, q8_0, q4_0, etc.) |
| `SD_RNG` | `--rng` | RNG backend (cuda, cpu) |
| `SD_THREADS` | `--threads` | CPU threads (-1 = auto) |
| `SD_PARAMS_BACKEND` | `--params-backend` | Where model weights are held, e.g. `diffusion=cpu,te=disk,vae=disk`. An explicit value disables automatic `--auto-fit` placement. Note: because the image sets `SD_OFFLOAD_CPU=1`, `*=cpu` is prepended to this value (`--offload-to-cpu` is a shorthand for `*=cpu`). Explicit per-module assignments still win over that `*=` default, so this is safe to combine; set `SD_OFFLOAD_CPU=0` for a clean value. |
| `SD_MAX_VRAM` | `--max-vram` | Per-device budget in GiB for managed weights during automatic graph-cut execution, e.g. `6` or `cuda0=6,vulkan0=4`. `0` uses live free VRAM; a negative value reserves that much free VRAM. |

## RunPod HuggingFace Model Caching

These env vars let you reference models cached via the [RunPod model caching
feature](https://docs.runpod.io/serverless/development/huggingface-models#use-cached-models).
They override the corresponding `SD_*` variables when set.

Format: `org/name/path` — trailing `/` denotes a directory, otherwise a file

| Env Variable | Overrides | Description |
|--------------|-----------|-------------|
| `RP_MODEL_PATH` | `SD_MODEL_PATH` | Cached HF model for `--model` |
| `RP_DIFFUSION_MODEL_PATH` | `SD_DIFFUSION_MODEL_PATH` | Cached HF model for `--diffusion-model` |
| `RP_VAE_PATH` | `SD_VAE_PATH` | Cached HF model for `--vae` |
| `RP_AUDIO_VAE_PATH` | `SD_AUDIO_VAE_PATH` | Cached HF model for `--audio-vae` |
| `RP_LLM_PATH` | `SD_LLM_PATH` | Cached HF model for `--llm` |
| `RP_LORA_DIR` | `SD_LORA_DIR` | Cached HF model directory for `--lora-model-dir` |

Each value is resolved to
`/runpod-volume/huggingface-cache/hub/models--{org}--{name}/snapshots/{hash}/{subpath}`.
A trailing `/` denotes a directory (the result gets a trailing `/`); otherwise it is treated as a file.

## Generation Defaults

None of these are set by default: each is forwarded as a server argument only
when the variable is non-empty, leaving sd-server to apply its own defaults.

These configure the **native `/sdcpp/v1/*` endpoints** (used in `loadbalancer`
mode). They do **not** change the defaults of the A1111-compatible
`/sdapi/v1/txt2img` and `/sdapi/v1/img2img` endpoints, which is what the
`queue` handler always calls:

| Field on the A1111 request | Default when omitted |
|---|---|
| `width` / `height` | `512`, per A1111 conventions |
| `steps` / `cfg_scale` | Inherited from these variables, else sd-server's `20` / `7.0` |
| `sampler_name` / `scheduler` | Model default |

For `img2img`, an omitted `width`/`height` instead derives the canvas from the
init image, so there is no way to express a server-side fallback there. Queue
clients that want a specific size must send `width`/`height` in the job input.

| Env Variable | CLI Arg | Description | Default   |
|--------------|---------|-------------|-----------|
| `SD_DEFAULT_WIDTH` | `--width` | Image width. Only passed when set; sd-server otherwise resolves to `512`. Native endpoints only (see above). | (unset) |
| `SD_DEFAULT_HEIGHT` | `--height` | Image height. Only passed when set; sd-server otherwise resolves to `512`. Native endpoints only (see above). | (unset) |
| `SD_DEFAULT_STEPS` | `--steps` | Sampling steps. Only passed when set; sd-server otherwise uses `20`. | (unset) |
| `SD_DEFAULT_CFG` | `--cfg-scale` | CFG scale. Only passed when set; sd-server otherwise uses `7.0`. | (unset) |
| `SD_DEFAULT_SAMPLER` | `--sampling-method` | Sampler. Only passed when set; sd-server otherwise picks it per model (`lcm` for PiD, `euler` for DiT-family models such as Flux/SD3/Wan/Qwen-Image, `euler_a` otherwise). Native endpoints only (see above). | (unset) |
| `SD_DEFAULT_SCHEDULER` | `--scheduler` | Sigma scheduler. Only passed when set; sd-server otherwise picks one from the model and sampler (e.g. `flux` for Flux, `flux2` for Flux2, `lcm` for LCM/TCD, `simple` for DDIM-trailing, `exponential` for EDM-v, else `discrete`). Native endpoints only (see above). | (unset) |
| `SD_DEFAULT_FLOW_SHIFT` | `--flow-shift` | Shift value for Flow models (SD3.x, WAN). Only passed when set; `--flow-shift auto` is otherwise used by sd-server. | (unset) |
| `SD_DEFAULT_SEED` | `--seed` | Default seed. Only passed when set; negative values request a random seed. | (unset) |
| `SD_DEFAULT_FPS` | `--fps` | Default frame rate for video generation. Only passed when set, so sd-server keeps its own default. | (unset) |
| `SD_DEFAULT_VIDEO_FRAMES` | `--video-frames` | Default number of video frames. Only passed when set, so sd-server keeps its own default. | (unset) |
| `SD_DEFAULT_REF_IMAGE_ARGS` | `--ref-image-args` | Reference-image key-value args, e.g. `ref_image_size=max` or `resize_before_vae=false`. | (unset) |

## Feature Flags

| Env Variable | CLI Flag | Description | Default |
|--------------|----------|-------------|---------|
| `SD_VAE_TILING` | `--vae-tiling` | Enable VAE tiling | (off) |
| `SD_OFFLOAD_CPU` | `--offload-to-cpu` | CPU offload. **On by default in the image** (`Dockerfile` sets `SD_OFFLOAD_CPU=1`). Set to `0` to disable. | `1` |
| `SD_FLASH_ATTN` | `--fa` | Flash attention. **On by default in the image** (`Dockerfile` sets `SD_FLASH_ATTN=1`). Deprecated upstream in favour of `--flash-attn on`. | `1` |
| `SD_DIFFUSION_FLASH_ATTN` | `--diffusion-fa` | Flash attention in diffusion model only. Deprecated upstream in favour of `--flash-attn off,diffusion=on`. | (off) |
| `SD_MMAP` | `--mmap` | Memory-map model weights | (off) |
| `SD_CLIP_ON_CPU` | `--clip-on-cpu` | Keep CLIP encoders on CPU. Deprecated upstream in favour of `--backend te=cpu`. | (off) |
| `SD_VAE_ON_CPU` | `--vae-on-cpu` | Keep VAE on CPU. Deprecated upstream in favour of `--backend vae=cpu`. | (off) |
| `SD_CONTROL_NET_CPU` | `--control-net-cpu` | Keep ControlNet on CPU. Deprecated upstream in favour of `--backend controlnet=cpu`. | (off) |
| `SD_SAGE_ATTN` | `--sage-attn` | Use native CUDA SageAttention in the diffusion model, with flash/default attention fallback | (off) |

## Handler Configuration

| Env Variable | Default | Description |
|--------------|---------|-------------|
| `SD_SERVER_URL` | `http://127.0.0.1:8080` | URL of the sd-server process |
| `HANDLER_TIMEOUT` | `300` | Request timeout in seconds |
| `CORS_ORIGINS` | `*` | Comma-separated list of allowed origins for CORS, or `*` to allow all origins. Used by FastAPI's CORSMiddleware in `loadbalancer` mode. |

## Endpoint Mode

| Env Variable | Default | Description |
|--------------|---------|-------------|
| `ENDPOINT_MODE` | `queue` | Selects which RunPod serverless endpoint type the worker runs as. `queue` (default) starts the `runpod` SDK handler that pulls jobs from the RunPod queue. `loadbalancer` starts a FastAPI reverse-proxy on `$PORT` (default 80) that exposes the A1111/OpenAI endpoints directly to the RunPod load balancer. |
| `PORT` | `80` | Listen port for the load-balancing FastAPI app. Ignored in `queue` mode. Must be added to the endpoint's env vars and to **Expose HTTP Ports** if changed from 80. |
| `PORT_HEALTH` | `=PORT` | **Read by the RunPod platform, not by our container.** Sets the port the load balancer probes `/ping` on. Leave unset so it tracks `PORT`: one uvicorn process then serves both traffic and the health check. Only set it to a different port if you also run a separate health server there — otherwise the probe targets a closed port, the worker never reports healthy, and requests hang until the ~2 min "no worker available" timeout. Ignored in `queue` mode. |
| `HEALTH_CHECK_PATH` | `/ping` | **Read by the RunPod platform.** Path the load balancer probes. Our app already serves `/ping`, so leave it unset. |
| `SD_READY_RETRIES` | `150` | How many times `startup.sh` polls sd-server's `/sdapi/v1/sd-models` before giving up. With the default interval this is a 5 minute budget for cold starts. |
| `SD_READY_INTERVAL` | `2` | Seconds to sleep between readiness polls in `startup.sh`. |
| `LOG_LEVEL` | `info` | uvicorn log level (`critical`, `error`, `warning`, `info`, `debug`, `trace`). Ignored in `queue` mode. |