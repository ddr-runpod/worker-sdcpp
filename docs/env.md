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
| `SD_TYPE` | `--type` | Quantization type (f32, f16, q8_0, q4_0, etc.) |
| `SD_RNG` | `--rng` | RNG backend (cuda, cpu) |
| `SD_THREADS` | `--threads` | CPU threads (-1 = auto) |

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

## Handler Configuration

| Env Variable | Default | Description |
|--------------|---------|-------------|
| `SD_SERVER_URL` | `http://127.0.0.1:8080` | URL of the sd-server process |
| `HANDLER_TIMEOUT` | `300` | Request timeout in seconds |