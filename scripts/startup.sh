#!/bin/bash
set -e

SERVER_ARGS=()

SERVER_ARGS+=("--listen-ip" "${SD_SERVER_HOST:-0.0.0.0}")
SERVER_ARGS+=("--listen-port" "${SD_SERVER_PORT:-8080}")

if [[ -n "$SD_MODEL_PATH" ]]; then
    SERVER_ARGS+=("--model" "$SD_MODEL_PATH")
fi

if [[ -n "$SD_CLIP_L_PATH" ]]; then
    SERVER_ARGS+=("--clip_l" "$SD_CLIP_L_PATH")
fi

if [[ -n "$SD_CLIP_G_PATH" ]]; then
    SERVER_ARGS+=("--clip_g" "$SD_CLIP_G_PATH")
fi

if [[ -n "$SD_T5XXL_PATH" ]]; then
    SERVER_ARGS+=("--t5xxl" "$SD_T5XXL_PATH")
fi

if [[ -n "$SD_LLM_PATH" ]]; then
    SERVER_ARGS+=("--llm" "$SD_LLM_PATH")
fi

if [[ -n "$SD_DIFFUSION_MODEL_PATH" ]]; then
    SERVER_ARGS+=("--diffusion-model" "$SD_DIFFUSION_MODEL_PATH")
fi

if [[ -n "$SD_VAE_PATH" ]]; then
    SERVER_ARGS+=("--vae" "$SD_VAE_PATH")
fi

if [[ -n "$SD_LORA_DIR" ]]; then
    SERVER_ARGS+=("--lora-model-dir" "$SD_LORA_DIR")
fi

if [[ -n "$SD_TYPE" ]]; then
    SERVER_ARGS+=("--type" "$SD_TYPE")
fi

if [[ -n "$SD_RNG" ]]; then
    SERVER_ARGS+=("--rng" "$SD_RNG")
fi

if [[ -n "$SD_THREADS" ]]; then
    SERVER_ARGS+=("--threads" "$SD_THREADS")
fi

SERVER_ARGS+=("--width" "${SD_DEFAULT_WIDTH:-512}")
SERVER_ARGS+=("--height" "${SD_DEFAULT_HEIGHT:-512}")
SERVER_ARGS+=("--steps" "${SD_DEFAULT_STEPS:-20}")
SERVER_ARGS+=("--cfg-scale" "${SD_DEFAULT_CFG:-7.0}")
SERVER_ARGS+=("--sampling-method" "${SD_DEFAULT_SAMPLER:-euler_a}")

[[ "$SD_VAE_TILING" == "1" ]] && SERVER_ARGS+=("--vae-tiling")
[[ "$SD_OFFLOAD_CPU" == "1" ]] && SERVER_ARGS+=("--offload-to-cpu")
[[ "$SD_FLASH_ATTN" == "1" ]] && SERVER_ARGS+=("--fa")
[[ "$SD_DIFFUSION_FLASH_ATTN" == "1" ]] && SERVER_ARGS+=("--diffusion-fa")
[[ "$SD_MMAP" == "1" ]] && SERVER_ARGS+=("--mmap")
[[ "$SD_CLIP_ON_CPU" == "1" ]] && SERVER_ARGS+=("--clip-on-cpu")
[[ "$SD_VAE_ON_CPU" == "1" ]] && SERVER_ARGS+=("--vae-on-cpu")
[[ "$SD_CONTROL_NET_CPU" == "1" ]] && SERVER_ARGS+=("--control-net-cpu")

SERVER_ARGS+=("--verbose")

echo "Starting sd-server with arguments:"
echo "${SERVER_ARGS[@]}"
echo ""

sd-server "${SERVER_ARGS[@]}" &
SERVER_PID=$!

export SD_SERVER_URL="http://127.0.0.1:${SD_SERVER_PORT:-8080}"

echo "Waiting for sd-server to be ready..."
until curl -sf "${SD_SERVER_URL}/sdapi/v1/sd-models" > /dev/null 2>&1; do
    if ! kill -0 "$SERVER_PID" 2>/dev/null; then
        echo "sd-server process died unexpectedly"
        exit 1
    fi
    echo "Waiting for server..."
    sleep 2
done

echo "sd-server is ready, starting handler..."

exec python -m src.handler
