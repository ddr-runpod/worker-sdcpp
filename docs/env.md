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
| `SD_LORA_DIR` | `--lora-model-dir` | Directory containing LoRA models |
| `RC_LORA_URL` | (none) | HTTP URL to download LoRA files from at startup via `rclone copy :http:`. Takes precedence over `SD_LORA_DIR` and `RP_LORA_DIR`. |
| `SD_TYPE` | `--type` | Quantization type (f32, f16, q8_0, q4_0, etc.) |
| `SD_RNG` | `--rng` | RNG backend (cuda, cpu) |
| `SD_THREADS` | `--threads` | CPU threads (-1 = auto) |

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
| `RP_LLM_PATH` | `SD_LLM_PATH` | Cached HF model for `--llm` |
| `RP_LORA_DIR` | `SD_LORA_DIR` | Cached HF model directory for `--lora-model-dir` |

Each value is resolved to
`/runpod-volume/huggingface-cache/hub/models--{org}--{name}/snapshots/{hash}/{subpath}`.
A trailing `/` denotes a directory (the result gets a trailing `/`); otherwise it is treated as a file.

## Generation Defaults

| Env Variable | CLI Arg | Description | Default |
|--------------|---------|-------------|---------|
| `SD_DEFAULT_WIDTH` | `--width` | Default image width | `512` |
| `SD_DEFAULT_HEIGHT` | `--height` | Default image height | `512` |
| `SD_DEFAULT_STEPS` | `--steps` | Default sampling steps | `20` |
| `SD_DEFAULT_CFG` | `--cfg-scale` | Default CFG scale | `7.0` |
| `SD_DEFAULT_SAMPLER` | `--sampling-method` | Default sampler | `euler_a` |

## Feature Flags

| Env Variable | CLI Flag | Description |
|--------------|----------|-------------|
| `SD_VAE_TILING` | `--vae-tiling` | Enable VAE tiling |
| `SD_OFFLOAD_CPU` | `--offload-to-cpu` | CPU offload |
| `SD_FLASH_ATTN` | `--fa` | Flash attention |
| `SD_DIFFUSION_FLASH_ATTN` | `--diffusion-fa` | Flash attention in diffusion model only |
| `SD_MMAP` | `--mmap` | Memory-map model weights |
| `SD_CLIP_ON_CPU` | `--clip-on-cpu` | Keep CLIP encoders on CPU |
| `SD_VAE_ON_CPU` | `--vae-on-cpu` | Keep VAE on CPU |
| `SD_CONTROL_NET_CPU` | `--control-net-cpu` | Keep ControlNet on CPU |
| `SD_DISABLE_AUTO_RESIZE_REF_IMAGE` | `--disable-auto-resize-ref-image` | Disable auto-resizing reference images | `1` |

## Handler Configuration

| Env Variable | Default | Description |
|--------------|---------|-------------|
| `SD_SERVER_URL` | `http://127.0.0.1:8080` | URL of the sd-server process |
| `HANDLER_TIMEOUT` | `300` | Request timeout in seconds |