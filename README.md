# RunPod Worker for stable-diffusion.cpp

A RunPod serverless worker using [stable-diffusion.cpp](https://github.com/leejet/stable-diffusion.cpp) for high-performance diffusion model inference. Uses the RunPod SDK to process queue-based jobs and forwards them to an A1111-compatible REST API server.

**Repository:** https://github.com/ddr-runpod/worker-sdcpp

## Features

- **A1111-Compatible API** - Drop-in replacement for Stable Diffusion WebUI
- **High Performance** - Pure C/C++ implementation with CUDA acceleration
- **Low Memory** - Supports GGUF quantization for reduced VRAM usage
- **Multi-Model Support** - SD 1.x, SD 2.x, SDXL, SD3, FLUX (one worker per model)

## Quick Start

### Prerequisites

- RunPod account with serverless access
- Docker installed locally
- Network volume with model files
- Docker Hub or container registry

### Build

```bash
git clone https://github.com/ddr-runpod/worker-sdcpp.git
cd worker-sdcpp

# Build with specific stable-diffusion.cpp commit (optional, defaults to 7397dda)
docker build --platform linux/amd64 \
  --build-arg SD_CPP_COMMIT=7397dda \
  -t ddr-runpod/worker-sdcpp:latest .

docker push ddr-runpod/worker-sdcpp:latest
```

### Deploy to RunPod

1. Go to [RunPod Console](https://console.runpod.io/serverless)
2. Click **New Endpoint**
3. Select **Import from Docker Registry**
4. Configure:
   - Container Image: `docker.io/ddr-runpod/worker-sdcpp:latest`
   - Volume Mount: Your network volume → `/models`
   - GPU: 16GB recommended (A100, A4000, A5000, etc.)
   - Port: 8080
5. Add environment variables:
   ```
   SD_MODEL_PATH=/models/your-model.gguf
   SD_SERVER_PORT=8080
   ```
6. Click **Deploy Endpoint**

## Configuration

All parameters are configured via environment variables at container startup.
See [docs/env.md](docs/env.md) for complete reference.

## Job Input Format

Jobs are submitted to the RunPod queue with a JSON payload containing the following structure:

### Common Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `mode` | string | `"txt2img"` | Generation mode: `"txt2img"` or `"img2img"` |
| `prompt` | string | - | Positive prompt (required) |
| `negative_prompt` | string | `""` | Negative prompt |
| `width` | int | `512` | Image width |
| `height` | int | `512` | Image height |
| `steps` | int | `20` | Sampling steps |
| `cfg_scale` | float | `7.0` | CFG scale |
| `seed` | int | `-1` | Random seed (-1 for random) |
| `sampler_name` | string | `"euler_a"` | Sampler name |
| `scheduler` | string | `"default"` | Scheduler name |

### txt2img Example

```json
{
  "mode": "txt2img",
  "prompt": "a beautiful sunset over mountains, cinematic, highly detailed",
  "negative_prompt": "blurry, low quality, distorted",
  "width": 1024,
  "height": 768,
  "steps": 25,
  "cfg_scale": 7.5,
  "seed": 12345,
  "sampler_name": "euler_a",
  "scheduler": "karras"
}
```

### img2img Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `init_images` | array | - | List of base64-encoded images (required) |
| `denoising_strength` | float | `0.75` | Denoising strength |
| `mask` | string | - | Base64-encoded mask (optional, for inpainting) |
| `extra_images` | array | - | List of base64-encoded reference images (optional) |

### img2img Example

```json
{
  "mode": "img2img",
  "prompt": "make it blue sky",
  "init_images": ["base64-encoded-image"],
  "denoising_strength": 0.6,
  "steps": 25,
  "seed": -1
}
```

### img2img with extra_images (ControlNet style)

```json
{
  "mode": "img2img",
  "prompt": "a cat sitting on a chair",
  "init_images": ["base64-encoded-image"],
  "extra_images": ["base64-encoded-pose-image"],
  "denoising_strength": 0.7,
  "steps": 25
}
```

## API Reference

### A1111-Compatible Endpoints

#### POST /sdapi/v1/txt2img

Text-to-image generation.

**Request:**
```json
{
  "prompt": "a beautiful sunset over mountains, cinematic, highly detailed",
  "negative_prompt": "blurry, low quality, distorted",
  "width": 1024,
  "height": 768,
  "steps": 25,
  "cfg_scale": 7.5,
  "seed": -1,
  "sampler_name": "euler_a",
  "scheduler": "karras",
  "batch_size": 1,
  "n_iter": 1
}
```

**Response:**
```json
{
  "images": ["base64-encoded-png-image"],
  "parameters": {
    "prompt": "...",
    "negative_prompt": "...",
    "seed": 12345,
    ...
  },
  "info": "{\"prompt\": \"...\", \"seed\": 12345, ...}"
}
```

#### POST /sdapi/v1/img2img

Image-to-image transformation with optional mask for inpainting.

**Request:**
```json
{
  "prompt": "make it blue sky",
  "init_images": ["base64-encoded-image"],
  "mask": "base64-encoded-mask",
  "denoising_strength": 0.6,
  "steps": 25,
  "seed": -1
}
```

**Response:** Same format as txt2img.

#### GET /sdapi/v1/loras

List available LoRA models.

**Response:**
```json
[
  {"name": "lora1.safetensors", "alias": "lora1"},
  {"name": "lora2.safetensors", "alias": "lora2"}
]
```

#### POST /sdapi/v1/refresh-loras

Refresh LoRA cache to detect new models.

**Response:** `{"reload": true}`

#### GET /sdapi/v1/samplers

List available sampling methods.

#### GET /sdapi/v1/schedulers

List available schedulers.

#### GET /sdapi/v1/sd-models

Get current model information.

#### GET /sdapi/v1/options

Get current server options.

### OpenAI-Compatible Endpoints

#### POST /v1/images/generations

**Request:**
```json
{
  "prompt": "a cute cat",
  "n": 1,
  "size": "512x512"
}
```

#### POST /v1/images/edits

Image editing/inpainting with OpenAI format.

### Samplers

| sd-server Name | A1111 Name |
|----------------|------------|
| `euler` | `Euler` |
| `euler_a` | `Euler a`, `k_euler_a` |
| `heun` | `Heun` |
| `dpm2` | `DPM2`, `k_dpm_2` |
| `dpm++2m` | `DPM++ 2M`, `k_dpmpp_2m` |
| `dpm++2mv2` | DPM++ 2M v2 |
| `dpm++2s_a` | DPM++ 2S a |
| `lcm` | `LCM` |
| `ddim_trailing` | `DDIM` |
| `res_multistep` | `Res multistep` |
| `res_2s` | `Res 2s` |

### Schedulers

`discrete`, `karras`, `exponential`, `ays`, `gits`, `smoothstep`, `sgm_uniform`, `simple`, `kl_optimal`, `lcm`, `bong_tangent`

## Supported Models

| Model Family | Status | Formats |
|--------------|--------|---------|
| SD 1.x | ✅ Supported | safetensors, GGUF |
| SD 2.x | ✅ Supported | safetensors, GGUF |
| SDXL | ✅ Supported | safetensors, GGUF |
| SD-Turbo | ✅ Supported | safetensors, GGUF |
| SDXL-Turbo | ✅ Supported | safetensors, GGUF |
| SD3/SD3.5 | ⚙️ To verify | Requires clip_l, clip_g, t5xxl |
| FLUX.1 | ⚙️ To verify | Requires clip_l, t5xxl, vae |
| FLUX.2 | ⚙️ To verify | Requires llm, vae |

### Model Directory Structure

```
/models/
├── v1-5-pruned.safetensors      # SD 1.5
├── v1-5-pruned.gguf             # Quantized SD 1.5
├── sdxl-base.safetensors        # SDXL
├── sdxl-base.Q5_K_M.gguf        # Quantized SDXL
├── flux1-dev.safetensors        # FLUX
├── flux1-dev.Q4_K_M.gguf        # Quantized FLUX
├── vae/
│   ├── sdxl-vae.safetensors
│   └── ae.safetensors           # FLUX VAE
├── text_encoders/
│   ├── clip_l.safetensors
│   ├── clip_g.safetensors
│   └── t5xxl_fp16.safetensors
└── loras/
    ├── lora1.safetensors
    └── lora2.safetensors
```

## Performance

### GPU Memory Requirements

| Model | Quantization | VRAM Required | Recommended GPU |
|-------|-------------|---------------|-----------------|
| SD 1.5 | f16 | ~4GB | RTX 3060, A4000 |
| SD 1.5 | q4_0 | ~2GB | Any 8GB+ GPU |
| SDXL | f16 | ~8GB | A5000, A6000, A100 |
| SDXL | q4_0 | ~4GB | RTX 4080, A5000 |
| FLUX.1-dev | q4_0 | ~12GB | A6000, A100 |
| FLUX.1-schnell | q4_0 | ~8GB | A5000, A100 |

### Optimization Tips

1. **Use VAE tiling** (`SD_VAE_TILING=1`) for high-resolution images
2. **Use CPU offload** (`SD_OFFLOAD_CPU=1`) for low VRAM situations
3. **Use quantized models** (GGUF) to reduce VRAM requirements
4. **Enable flash attention** (`SD_FLASH_ATTN=1`) for memory savings on CUDA

## Testing

### Local Testing

```bash
# Start the server locally (requires CUDA)
./scripts/startup.sh

# Or with environment variables:
SD_MODEL_PATH=/path/to/model.gguf SD_SERVER_PORT=8080 ./scripts/startup.sh

# In another terminal, send a test request:
curl -X POST http://localhost:8080/sdapi/v1/txt2img \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "a cute cat",
    "steps": 20,
    "width": 512,
    "height": 512
  }' > output.json

# Extract and decode the image:
python3 -c "
import base64, json
with open('output.json') as f:
    data = json.load(f)
with open('output.png', 'wb') as f:
    f.write(base64.b64decode(data['images'][0]))
"
```

## Known Limitations

| Limitation | Description | Workaround |
|------------|-------------|------------|
| No runtime model switching | Model loaded once at startup | Deploy multiple workers, one per model |
| No progress endpoint | `/sdapi/v1/progress` not implemented | Client waits for full response |
| No interrupt/skip | Cannot cancel running generation | Wait for completion |
| Sequential processing | One generation at a time | Increase concurrent workers in RunPod |

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Out of memory | Model too large for GPU | Use quantization or enable offloading |
| Slow inference | CPU fallback | Ensure CUDA is available and working |
| Model not found | Wrong path | Verify `SD_MODEL_PATH` points to actual file |
| Black images | T5 model on GPU | Set `SD_CLIP_ON_CPU=1` for FLUX/SD3 |

### Health Check

The server responds with HTTP 200 on `GET /sdapi/v1/sd-models` if healthy.

## References

- [stable-diffusion.cpp](https://github.com/leejet/stable-diffusion.cpp)
- [stable-diffusion-cpp-python](https://github.com/william-murray1204/stable-diffusion-cpp-python)
- [RunPod Serverless Documentation](https://docs.runpod.io/serverless)
- [A1111 WebUI API](https://github.com/AUTOMATIC1111/stable-diffusion-webui/wiki/API)
