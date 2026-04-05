# sd-server Command Line Parameters

This document lists all parameters that can be passed to the `sd-server` binary when starting the Stable Diffusion server.

## Server Options

| Short | Long | Description | Default |
|-------|------|-------------|---------|
| `-l` | `--listen-ip` | Server listen IP address | `127.0.0.1` |
| | `--listen-port` | Server listen port | `1234` |
| | `--serve-html-path` | Path to HTML file to serve at root (optional) | |
| `-v` | `--verbose` | Print extra debug info | `false` |
| | `--color` | Color the logging tags according to level | `false` |
| `-h` | `--help` | Show help message and exit | |

## Context Options (Model Loading)

### Model Paths

| Short | Long | Description |
|-------|------|-------------|
| `-m` | `--model` | Path to full model (main diffusion model) |
| | `--clip_l` | Path to the CLIP-L text encoder (SDXL/SD3/FLUX) |
| | `--clip_g` | Path to the CLIP-G text encoder (SD3) |
| | `--clip_vision` | Path to the CLIP-VISION encoder |
| | `--t5xxl` | Path to the T5XXL text encoder (FLUX/SD3) |
| | `--llm` | Path to the LLM text encoder (qwenvl2.5 for qwen-image, mistral-small3.2 for flux2) |
| | `--llm_vision` | Path to the LLM vision encoder |
| | `--qwen2vl` | Alias of `--llm` (deprecated) |
| | `--qwen2vl_vision` | Alias of `--llm_vision` (deprecated) |
| | `--diffusion-model` | Path to standalone diffusion model |
| | `--high-noise-diffusion-model` | Path to standalone high noise diffusion model |
| | `--vae` | Path to standalone VAE model |
| | `--taesd` | Path to Tiny AutoEncoder for fast decoding (low quality) |
| | `--tae` | Alias of `--taesd` |
| | `--control-net` | Path to ControlNet model |
| | `--embd-dir` | Embeddings directory |
| | `--lora-model-dir` | LoRA model directory |
| | `--photo-maker` | Path to PHOTOMAKER model |
| | `--upscale-model` | Path to ESRGAN model |

### Computation Options

| Short | Long | Description | Default |
|-------|------|-------------|---------|
| `-t` | `--threads` | Number of CPU threads (-1 = auto) | `-1` |
| | `--chroma-t5-mask-pad` | T5 mask pad size of chroma | `1` |

### Weight Type

| Long | Description |
|------|-------------|
| `--type` | Weight type for model quantization. Examples: `f32`, `f16`, `q4_0`, `q4_1`, `q5_0`, `q5_1`, `q8_0`, `q2_K`, `q3_K`, `q4_K`. If not specified, defaults to the type in the weight file |

### RNG Options

| Long | Description | Default |
|------|-------------|---------|
| `--rng` | RNG type: `std_default`, `cuda` (SD-WebUI), `cpu` (ComfyUI) | `cuda` |
| `--sampler-rng` | Sampler RNG type. If not specified, uses `--rng` value | |

### Model Behavior Flags

| Long | Description |
|------|-------------|
| `--force-sdxl-vae-conv-scale` | Force use of conv scale on SDXL VAE |
| `--offload-to-cpu` | Place weights in RAM to save VRAM, auto-load to VRAM when needed |
| `--mmap` | Memory-map model weights |
| `--control-net-cpu` | Keep ControlNet in CPU (for low VRAM) |
| `--clip-on-cpu` | Keep CLIP in CPU (for low VRAM) |
| `--vae-on-cpu` | Keep VAE in CPU (for low VRAM) |
| `--fa` | Use flash attention |
| `--diffusion-fa` | Use flash attention in diffusion model only |
| `--diffusion-conv-direct` | Use `ggml_conv2d_direct` in diffusion model |
| `--vae-conv-direct` | Use `ggml_conv2d_direct` in VAE model |
| `--circular` | Enable circular padding for convolutions |
| `--circularx` | Enable circular RoPE wrapping on x-axis (width) only |
| `--circulary` | Enable circular RoPE wrapping on y-axis (height) only |
| `--chroma-disable-dit-mask` | Disable DiT mask for chroma |
| `--chroma-enable-t5-mask` | Enable T5 mask for chroma |
| `--qwen-image-zero-cond-t` | Enable `zero_cond_t` for qwen image |

### Advanced Options

| Long | Description |
|------|-------------|
| `--prediction` | Prediction type override: `eps`, `v`, `edm_v`, `sd3_flow`, `flux_flow`, `flux2_flow` |
| `--lora-apply-mode` | LoRA application mode: `auto`, `immediately`, `at_runtime` (default: `auto`) |
| `--tensor-type-rules` | Weight type per tensor pattern (e.g., `^vae\.=f16,model\.=q8_0`) |

## Default Generation Options

### Image Settings

| Short | Long | Description | Default |
|-------|------|-------------|---------|
| `-W` | `--width` | Image width in pixels | `512` |
| `-H` | `--height` | Image height in pixels | `512` |
| `-b` | `--batch-count` | Number of images to generate | `1` |
| | `--steps` | Number of sample steps | `20` |
| | `--high-noise-steps` | High noise phase sample steps | `-1` (auto) |
| | `--clip-skip` | Ignore last N layers of CLIP (1=SD1.x, 2=SD2.x) | `-1` |

### Prompt Settings

| Short | Long | Description |
|-------|------|-------------|
| `-p` | `--prompt` | The prompt to render |
| `-n` | `--negative-prompt` | The negative prompt |
| `-r` | `--ref-image` | Reference image for Flux Kontext models (can be used multiple times) |

### Guidance & Sampling

| Short | Long | Description | Default |
|-------|------|-------------|---------|
| | `--cfg-scale` | Unconditional guidance scale | `7.0` |
| | `--img-cfg-scale` | Image guidance scale for inpaint/instruct-pix2pix | (same as `--cfg-scale`) |
| | `--guidance` | Distilled guidance scale for models with guidance input | `3.5` |
| | `--slg-scale` | Skip Layer Guidance (SLG) scale (DiT models only, 0=disabled) | `0` |
| | `--skip-layer-start` | SLG enabling point | `0.01` |
| | `--skip-layer-end` | SLG disabling point | `0.2` |
| | `--eta` | Noise multiplier | `0` (varies by sampler) |
| | `--flow-shift` | Shift value for Flow models (SD3.x, WAN) | `auto` |
| | `--sampling-method` | Sampling method (see below) | `euler_a` (varies by model) |
| | `--scheduler` | Denoiser sigma scheduler (see below) | `discrete` |
| | `--sigmas` | Custom sigma values (comma-separated, e.g., `14.61,7.8,3.5,0.0`) | |
| | `--skip-layers` | Layers to skip for SLG steps | `[7,8,9]` |
| | `--high-noise-skip-layers` | High noise phase SLG layers | `[7,8,9]` |
| | `--timestep-shift` | Shift timestep for NitroFusion models | `0` |

### Image-to-Image & Inpainting

| Short | Long | Description | Default |
|-------|------|-------------|---------|
| `-i` | `--init-img` | Path to init/control image | |
| | `--end-img` | Path to end image (required by FLF2V) | |
| | `--mask` | Path to mask image | |
| | `--control-image` | Path to ControlNet control image | |
| | `--control-video` | Path to control video frames directory | |
| | `--strength` | Denoising strength for img2img | `0.75` |
| | `--control-strength` | ControlNet strength | `0.9` |
| | `--increase-ref-index` | Auto-increment reference image indices | `false` |
| | `--disable-auto-resize-ref-image` | Disable auto-resize of reference images | `false` |

### PhotoMaker Options

| Long | Description |
|------|-------------|
| `--pm-id-images-dir` | PhotoMaker input ID images directory |
| `--pm-id-embed-path` | PhotoMaker v2 ID embed path |
| `--pm-style-strength` | PhotoMaker style strength | `20` |

### VAE Tiling

| Long | Description | Default |
|------|-------------|---------|
| `--vae-tiling` | Process VAE in tiles to reduce memory | `false` |
| `--vae-tile-size` | Tile size (format: `XxY` or single value) | `32x32` |
| `--vae-relative-tile-size` | Relative tile size (fraction if <1, count if >=1) | |
| `--vae-tile-overlap` | Tile overlap as fraction of tile size | `0.5` |

### Upscaling

| Long | Description | Default |
|------|-------------|---------|
| `--upscale-repeats` | Number of ESRGAN upscaler passes | `1` |
| `--upscale-tile-size` | Tile size for ESRGAN | `128` |

### Video Generation

| Long | Description | Default |
|-------|-------------|---------|
| `--video-frames` | Number of video frames | `1` |
| `--fps` | Frames per second | `16` |

### Caching Modes

| Long | Description |
|------|-------------|
| `--cache-mode` | Caching method: `easycache` (DiT), `ucache` (UNET), `dbcache`/`taylorseer`/`cache-dit` (DiT block-level), `spectrum` (UNET/DiT Chebyshev+Taylor) |
| `--cache-option` | Named cache params in `key=value` format (see below) |
| `--scm-mask` | SCM steps mask for cache-dit (comma-separated 0/1) |
| `--scm-policy` | SCM policy: `dynamic` or `static` |

#### Cache Option Examples

```
# easycache/ucache
threshold=,start=,end=,decay=,relative=,reset=

# dbcache/taylorseer/cache-dit
Fn=,Bn=,threshold=,warmup=

# spectrum
w=,m=,lam=,window=,flex=,warmup=,stop=

# Examples:
"threshold=0.25"
"threshold=1.5,reset=0"
```

### Special Model Parameters

| Long | Description | Default |
|-------|-------------|---------|
| `--moe-boundary` | Timestep boundary for Wan2.2 MoE model | `0.875` |
| `--vace-strength` | WAN VACE strength | `1.0` |

### Output Options

| Long | Description | Default |
|-------|-------------|---------|
| `--disable-image-metadata` | Do not embed generation metadata on image files | `false` |

### Seed

| Short | Long | Description | Default |
|-------|------|-------------|---------|
| `-s` | `--seed` | RNG seed (use random seed if < 0) | `42` |

## Sampling Methods

Available sampling methods:

- `euler` - Euler
- `euler_a` - Euler Ancestral
- `heun` - Heun
- `dpm2` - DPM2
- `dpm++2s_a` - DPM++ 2S Ancestral
- `dpm++2m` - DPM++ 2M
- `dpm++2mv2` - DPM++ 2M Karras
- `ipndm` - iPNDM
- `ipndm_v` - iPNDM Variable
- `lcm` - LCM (Latent Consistency Model)
- `ddim_trailing` - DDIM Trailing
- `tcd` - TCD
- `res_multistep` - Restart Multistep
- `res_2s` - Restart 2S

## Schedulers

Available schedulers:

- `discrete` - Discrete
- `karras` - Karras
- `exponential` - Exponential
- `ays` - AYS
- `gits` - GITS
- `smoothstep` - Smoothstep
- `sgm_uniform` - SGM Uniform
- `simple` - Simple
- `kl_optimal` - KL Optimal
- `lcm` - LCM
- `bong_tangent` - Bong Tangent

## Example Usage

```bash
# Basic server startup
sd-server -l 0.0.0.0 --listen-port 8080 -m /models/sdxl.safetensors

# With VAE and LoRA support
sd-server -m /models/sdxl.safetensors \
  --vae /models/sdxl-vae.safetensors \
  --lora-model-dir /models/loras \
  --offload-to-cpu

# With SDXL encoders
sd-server -m /models/sdxl.safetensors \
  --clip_l /models/clip_l.safetensors \
  --clip_g /models/clip_g.safetensors

# With flash attention
sd-server -m /models/sdxl.safetensors --fa --mmap
```

## Environment Variable Mapping

For container deployment, these parameters map to environment variables:

| Parameter | Environment Variable |
|-----------|---------------------|
| `--listen-ip` | `SD_SERVER_HOST` |
| `--listen-port` | `SD_SERVER_PORT` |
| `--model` | `SD_MODEL_PATH` |
| `--diffusion-model` | `SD_DIFFUSION_MODEL_PATH` |
| `--clip_l` | `SD_CLIP_L_PATH` |
| `--clip_g` | `SD_CLIP_G_PATH` |
| `--t5xxl` | `SD_T5XXL_PATH` |
| `--llm` | `SD_LLM_PATH` |
| `--vae` | `SD_VAE_PATH` |
| `--lora-model-dir` | `SD_LORA_DIR` |
| `--type` | `SD_TYPE` |
| `--rng` | `SD_RNG` |
| `--threads` | `SD_THREADS` |
| `--width` | `SD_DEFAULT_WIDTH` |
| `--height` | `SD_DEFAULT_HEIGHT` |
| `--steps` | `SD_DEFAULT_STEPS` |
| `--cfg-scale` | `SD_DEFAULT_CFG` |
| `--sampling-method` | `SD_DEFAULT_SAMPLER` |
| `--vae-tiling` | `SD_VAE_TILING` |
| `--offload-to-cpu` | `SD_OFFLOAD_CPU` |
| `--fa` | `SD_FLASH_ATTN` |
| `--diffusion-fa` | `SD_DIFFUSION_FLASH_ATTN` |
| `--mmap` | `SD_MMAP` |
