# Stable Diffusion Server API

The sd-server exposes an A1111-compatible REST API for image generation and model management.

## Base URL

```
http://{host}:{port}
```

## CORS

CORS is enabled for all origins by default. The server responds to `OPTIONS` preflight requests with appropriate CORS headers.

---

## Text-to-Image

### `POST /sdapi/v1/txt2img`

Generate images from a text prompt.

#### Request Body

```json
{
  "prompt": "a beautiful landscape",
  "negative_prompt": "blurry, low quality",
  "width": 512,
  "height": 512,
  "steps": 20,
  "cfg_scale": 7.0,
  "seed": -1,
  "batch_size": 1,
  "clip_skip": -1,
  "sampler_name": "euler_a",
  "scheduler": "default",
  "lora": [
    {
      "path": "my_lora.safetensors",
      "multiplier": 1.0,
      "is_high_noise": false
    }
  ]
}
```

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `prompt` | string | Yes | - | Positive prompt for generation |
| `negative_prompt` | string | No | `""` | Negative prompt |
| `width` | integer | No | `512` | Image width (pixels) |
| `height` | integer | No | `512` | Image height (pixels) |
| `steps` | integer | No | Server default | Number of sampling steps (1-150) |
| `cfg_scale` | float | No | `7.0` | CFG/guidance scale |
| `seed` | integer | No | `-1` | Random seed. `-1` for random seed |
| `batch_size` | integer | No | `1` | Number of images per batch (1-8) |
| `clip_skip` | integer | No | `-1` | CLIP skip layers (<=0 = auto) |
| `sampler_name` | string | No | Server default | Sampling method |
| `scheduler` | string | No | `default` | Scheduler name |
| `lora` | array | No | `[]` | LoRA models to apply |

#### LoRA Object

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `path` | string | Yes | - | LoRA filename (from lora directory) |
| `multiplier` | float | No | `1.0` | LoRA strength multiplier |
| `is_high_noise` | boolean | No | `false` | Apply to high-noise phase |

#### Response

```json
{
  "images": [
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
  ],
  "parameters": {
    "prompt": "a beautiful landscape",
    ...
  },
  "info": ""
}
```

| Field | Type | Description |
|-------|------|-------------|
| `images` | array | Base64-encoded PNG images |
| `parameters` | object | Echo of input parameters |
| `info` | string | Additional info (empty) |

---

## Image-to-Image

### `POST /sdapi/v1/img2img`

Generate images from an init image (for img2img, inpainting, or control).

#### Request Body

```json
{
  "prompt": "a cyberpunk city",
  "negative_prompt": "blurry",
  "init_images": ["data:image/png;base64,..."],
  "mask": "data:image/png;base64,...",
  "inpainting_mask_invert": 0,
  "width": 512,
  "height": 512,
  "steps": 20,
  "cfg_scale": 7.0,
  "denoising_strength": 0.75,
  "seed": -1,
  "batch_size": 1,
  "clip_skip": -1,
  "sampler_name": "euler_a",
  "scheduler": "default",
  "extra_images": ["data:image/png;base64,..."],
  "lora": [...]
}
```

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `prompt` | string | Yes | - | Positive prompt |
| `negative_prompt` | string | No | `""` | Negative prompt |
| `init_images` | array | No | - | Base64-encoded init images |
| `mask` | string | No | - | Base64-encoded inpainting mask |
| `inpainting_mask_invert` | integer | No | `0` | `1` to invert mask |
| `denoising_strength` | float | No | `-1` | Denoising strength (0.0-1.0) |
| `extra_images` | array | No | - | Extra reference images (base64) |
| `width` | integer | No | `512` | Target width |
| `height` | integer | No | `512` | Target height |
| `steps` | integer | No | Server default | Sampling steps (1-150) |
| `cfg_scale` | float | No | `7.0` | CFG scale |
| `seed` | integer | No | `-1` | Random seed |
| `batch_size` | integer | No | `1` | Batch count (1-8) |
| `clip_skip` | integer | No | `-1` | CLIP skip |
| `sampler_name` | string | No | Server default | Sampler |
| `scheduler` | string | No | `default` | Scheduler |
| `lora` | array | No | `[]` | LoRA models |

#### Response

```json
{
  "images": ["iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="],
  "parameters": { ... },
  "info": ""
}
```

---

## Model Information

### `GET /sdapi/v1/sd-models`

Get information about the currently loaded model.

#### Response

```json
[
  {
    "title": "sdxl",
    "model_name": "sdxl",
    "filename": "sdxl.safetensors",
    "hash": "8888888888",
    "sha256": "8888888888888888888888888888888888888888888888888888888888888888",
    "config": null
  }
]
```

### `GET /sdapi/v1/options`

Get current server options.

#### Response

```json
{
  "samples_format": "png",
  "sd_model_checkpoint": "sdxl"
}
```

---

## LoRA Management

### `GET /sdapi/v1/loras`

List available LoRA models from the configured LoRA directory.

#### Response

```json
[
  {
    "name": "my_lora",
    "path": "my_lora.safetensors"
  },
  {
    "name": "another_lora",
    "path": "subfolder/another_lora.gguf"
  }
]
```

---

## Samplers & Schedulers

### `GET /sdapi/v1/samplers`

List available sampling methods.

#### Response

```json
[
  {
    "name": "default",
    "aliases": ["default"],
    "options": {}
  },
  {
    "name": "Euler",
    "aliases": ["Euler"],
    "options": {}
  },
  {
    "name": "Euler a",
    "aliases": ["Euler a"],
    "options": {}
  },
  {
    "name": "DPM++ 2M",
    "aliases": ["DPM++ 2M"],
    "options": {}
  }
]
```

### `GET /sdapi/v1/schedulers`

List available schedulers.

#### Response

```json
[
  {
    "name": "default",
    "label": "default"
  },
  {
    "name": "discrete",
    "label": "discrete"
  },
  {
    "name": "karras",
    "label": "karras"
  }
]
```

---

## OpenAI-Compatible API

### `GET /v1/models`

List available models.

#### Response

```json
{
  "object": "list",
  "data": [
    {
      "id": "sd-cpp-local",
      "object": "model",
      "owned_by": "local"
    }
  ]
}
```

---

### `POST /v1/images/generations`

Generate images (OpenAI-compatible).

#### Request Body

```json
{
  "prompt": "a cat sitting on a windowsill",
  "n": 1,
  "size": "512x512",
  "output_format": "png",
  "output_compression": 100
}
```

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `prompt` | string | Yes | - | Generation prompt |
| `n` | integer | No | `1` | Number of images (1-8) |
| `size` | string | No | Server default | Image size (e.g., `512x512`, `1024x1024`) |
| `output_format` | string | No | `png` | Output format: `png`, `jpeg`, `webp` |
| `output_compression` | integer | No | `100` | Compression quality (0-100) |

#### Response

```json
{
  "created": 1704067200,
  "data": [
    {
      "b64_json": "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
    }
  ],
  "output_format": "png"
}
```

---

### `POST /v1/images/edits`

Edit images with prompt (OpenAI-compatible, supports inpainting).

#### Request Body (multipart/form-data)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `prompt` | string | Yes | Edit prompt |
| `image[]` | file | Yes | Input image(s) |
| `mask` | file | No | Inpainting mask |
| `n` | integer | No | Number of outputs (1-8) |
| `size` | string | No | Output size |
| `output_format` | string | No | `png` or `jpeg` |
| `output_compression` | integer | No | Compression quality (0-100) |

#### Response

```json
{
  "created": 1704067200,
  "data": [
    {
      "b64_json": "..."
    }
  ],
  "output_format": "png"
}
```

---

## Error Responses

All endpoints return JSON error responses on failure:

```json
{
  "error": "error_code",
  "message": "Human-readable error message"
}
```

### Common Error Codes

| Status | Error Code | Description |
|--------|------------|-------------|
| 400 | `empty body` | Request body is empty |
| 400 | `prompt required` | Prompt field is missing or empty |
| 400 | `width and height must be positive` | Invalid dimensions |
| 400 | `steps must be in range [1, 150]` | Invalid step count |
| 400 | `batch_size must be in range [1, 8]` | Invalid batch size |
| 400 | `invalid output_format` | Unsupported output format |
| 400 | `invalid lora path` | LoRA file not found |
| 400 | `invalid params` | Invalid generation parameters |
| 500 | `server_error` | Internal server error |

---

## Client Examples

### cURL

```bash
# Text-to-Image
curl -X POST http://localhost:8080/sdapi/v1/txt2img \
  -H "Content-Type: application/json" \
  -d '{"prompt": "a beautiful sunset", "steps": 20}'

# Image-to-Image
curl -X POST http://localhost:8080/sdapi/v1/img2img \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "turn to winter",
    "init_images": ["data:image/png;base64,..."],
    "denoising_strength": 0.7
  }'

# Get LoRA list
curl http://localhost:8080/sdapi/v1/loras

# OpenAI-compatible generation
curl -X POST http://localhost:8080/v1/images/generations \
  -H "Content-Type: application/json" \
  -d '{"prompt": "a cat", "n": 2, "size": "512x512"}'
```

### Python

```python
import requests
import base64

# Text-to-Image
response = requests.post(
    "http://localhost:8080/sdapi/v1/txt2img",
    json={
        "prompt": "a beautiful landscape",
        "steps": 25,
        "cfg_scale": 7.5,
        "seed": 42
    }
)
data = response.json()
image_data = base64.b64decode(data["images"][0])

# Image-to-Image
with open("input.png", "rb") as f:
    img_b64 = base64.b64encode(f.read()).decode()

response = requests.post(
    "http://localhost:8080/sdapi/v1/img2img",
    json={
        "prompt": "turn blue",
        "init_images": [f"data:image/png;base64,{img_b64}"],
        "denoising_strength": 0.5
    }
)

# List LoRAs
loras = requests.get("http://localhost:8080/sdapi/v1/loras").json()
for lora in loras:
    print(f"{lora['name']}: {lora['path']}")
```

### JavaScript/Node.js

```javascript
// Text-to-Image
const response = await fetch('http://localhost:8080/sdapi/v1/txt2img', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    prompt: 'a fantasy castle',
    steps: 30,
    width: 768,
    height: 768
  })
});

const data = await response.json();
const imageBuffer = Buffer.from(data.images[0], 'base64');

// Image-to-Image
const formData = new FormData();
formData.append('prompt', 'add snow');
formData.append('image[]', fileBuffer, 'input.png');

const img2imgResponse = await fetch('http://localhost:8080/v1/images/edits', {
  method: 'POST',
  body: formData
});
```
