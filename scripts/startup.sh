#!/bin/bash
set -e

SERVER_ARGS=()

SERVER_ARGS+=("--listen-ip" "${SD_SERVER_HOST:-0.0.0.0}")
SERVER_ARGS+=("--listen-port" "${SD_SERVER_PORT:-8080}")

dump_runpod_cache_tree() {
    echo "Contents of /runpod-volume/huggingface-cache/hub/:" >&2
    find "/runpod-volume/huggingface-cache/hub/" -maxdepth 5 -type f -o -type d 2>/dev/null | head -200 >&2 || true
}

resolve_runpod_cache_path() {
    local path="$1"
    local is_dir=false
    [[ "$path" == */ ]] && is_dir=true
    path="${path%/}"

    local org="${path%%/*}"
    local rest="${path#*/}"
    local name="${rest%%/*}"
    local subpath=""
    [[ "$rest" == */* ]] && subpath="${rest#*/}"

    if [[ -z "$org" || -z "$name" ]]; then
        echo "ERROR: RunPod cache path must be in 'org/name/...' format, got: $1" >&2
        exit 1
    fi

    if ! $is_dir && [[ -z "$subpath" ]]; then
        echo "ERROR: RunPod cache path for a file must include a filename, got: $1" >&2
        exit 1
    fi

    local cache_dir="/runpod-volume/huggingface-cache/hub/models--${org,,}--${name,,}"
    local refs_file="$cache_dir/refs/main"
    local snapshots_dir="$cache_dir/snapshots"

    local snapshot_hash=""
    if [[ -f "$refs_file" ]]; then
        snapshot_hash=$(cat "$refs_file")
    fi
    if [[ -z "$snapshot_hash" && -d "$snapshots_dir" ]]; then
        snapshot_hash=$(ls -1 "$snapshots_dir" | sort | head -1)
    fi
    if [[ -z "$snapshot_hash" ]]; then
        echo "ERROR: RunPod cached model not found for '$1'" >&2
        echo "Checked: $cache_dir" >&2
        dump_runpod_cache_tree
        exit 1
    fi

    local result="$snapshots_dir/$snapshot_hash"
    [[ -n "$subpath" ]] && result="$result/$subpath"
    $is_dir && result="$result/"

    if $is_dir; then
        if [[ ! -d "$result" ]]; then
            echo "ERROR: RunPod cached model directory not found: $result" >&2
            dump_runpod_cache_tree
            exit 1
        fi
    else
        if [[ ! -f "$result" ]]; then
            echo "ERROR: RunPod cached model file not found: $result" >&2
            dump_runpod_cache_tree
            exit 1
        fi
    fi

    echo "$result"
}

[[ -n "$RP_MODEL_PATH" ]] && SD_MODEL_PATH=$(resolve_runpod_cache_path "$RP_MODEL_PATH")
[[ -n "$RP_DIFFUSION_MODEL_PATH" ]] && SD_DIFFUSION_MODEL_PATH=$(resolve_runpod_cache_path "$RP_DIFFUSION_MODEL_PATH")
[[ -n "$RP_VAE_PATH" ]] && SD_VAE_PATH=$(resolve_runpod_cache_path "$RP_VAE_PATH")
[[ -n "$RP_LLM_PATH" ]] && SD_LLM_PATH=$(resolve_runpod_cache_path "$RP_LLM_PATH")
[[ -n "$RP_LORA_DIR" ]] && SD_LORA_DIR=$(resolve_runpod_cache_path "$RP_LORA_DIR")

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

SERVER_ARGS+=("--width" "${SD_DEFAULT_WIDTH:-1024}")
SERVER_ARGS+=("--height" "${SD_DEFAULT_HEIGHT:-1024}")
SERVER_ARGS+=("--steps" "${SD_DEFAULT_STEPS:-20}")
SERVER_ARGS+=("--cfg-scale" "${SD_DEFAULT_CFG:-7.0}")
SERVER_ARGS+=("--sampling-method" "${SD_DEFAULT_SAMPLER:-euler_a}")

[[ "$SD_VERBOSE" == "1" ]] && SERVER_ARGS+=("--verbose")
[[ "$SD_VAE_TILING" == "1" ]] && SERVER_ARGS+=("--vae-tiling")
[[ "$SD_OFFLOAD_CPU" == "1" ]] && SERVER_ARGS+=("--offload-to-cpu")
[[ "$SD_FLASH_ATTN" == "1" ]] && SERVER_ARGS+=("--fa")
[[ "$SD_DIFFUSION_FLASH_ATTN" == "1" ]] && SERVER_ARGS+=("--diffusion-fa")
[[ "$SD_MMAP" == "1" ]] && SERVER_ARGS+=("--mmap")
[[ "$SD_CLIP_ON_CPU" == "1" ]] && SERVER_ARGS+=("--clip-on-cpu")
[[ "$SD_VAE_ON_CPU" == "1" ]] && SERVER_ARGS+=("--vae-on-cpu")
[[ "$SD_CONTROL_NET_CPU" == "1" ]] && SERVER_ARGS+=("--control-net-cpu")
[[ "${SD_DISABLE_AUTO_RESIZE_REF_IMAGE:-1}" == "1" ]] && SERVER_ARGS+=("--disable-auto-resize-ref-image")

echo "Starting sd-server with arguments:"
echo "${SERVER_ARGS[@]}"
echo ""

sd-server "${SERVER_ARGS[@]}" &
SERVER_PID=$!

export SD_SERVER_URL="http://127.0.0.1:${SD_SERVER_PORT:-8080}"

echo "Waiting for sd-server to be ready..."
until curl -sf "${SD_SERVER_URL}/sdapi/v1/loras" > /dev/null 2>&1; do
    if ! kill -0 "$SERVER_PID" 2>/dev/null; then
        echo "sd-server process died unexpectedly"
        exit 1
    fi
    echo "Waiting for server..."
    sleep 2
done

echo "sd-server is ready, starting handler..."

exec python -m src.handler
