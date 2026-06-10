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

| Env Variable | CLI Arg | Description | Default   |
|--------------|---------|-------------|-----------|
| `SD_DEFAULT_WIDTH` | `--width` | Default image width | `1024`    |
| `SD_DEFAULT_HEIGHT` | `--height` | Default image height | `1024`     |
| `SD_DEFAULT_STEPS` | `--steps` | Default sampling steps | `20`      |
| `SD_DEFAULT_CFG` | `--cfg-scale` | Default CFG scale | `7.0`     |
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

## Endpoint Mode

| Env Variable | Default | Description |
|--------------|---------|-------------|
| `ENDPOINT_MODE` | `queue` | Selects which RunPod serverless endpoint type the worker runs as. `queue` (default) starts the `runpod` SDK handler that pulls jobs from the RunPod queue. `loadbalancer` starts a FastAPI reverse-proxy on `$PORT` (default 80) that exposes the A1111/OpenAI endpoints directly to the RunPod load balancer. |
| `PORT` | `80` | Listen port for the load-balancing FastAPI app. Ignored in `queue` mode. Must be added to the endpoint's env vars and to **Expose HTTP Ports** if changed from 80. |
| `PORT_HEALTH` | `=PORT` | Port the RunPod load balancer probes `/ping` on. Defaults to `PORT`, so a single FastAPI process serves both traffic and the health check. Ignored in `queue` mode. |
| `LOG_LEVEL` | `info` | uvicorn log level (`critical`, `error`, `warning`, `info`, `debug`, `trace`). Ignored in `queue` mode. |