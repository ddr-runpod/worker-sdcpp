#!/bin/bash
set -eo pipefail

echo "worker-sdcpp version: $(cat /VERSION)"

# Effective host/port resolved once so every consumer (server args, readiness
# URL, handler URL) stays in sync and the fallbacks can't drift.
SD_SERVER_HOST="${SD_SERVER_HOST:-0.0.0.0}"
SD_SERVER_PORT="${SD_SERVER_PORT:-8080}"

SERVER_ARGS=()
SERVER_ARGS+=("--listen-ip" "$SD_SERVER_HOST")
SERVER_ARGS+=("--listen-port" "$SD_SERVER_PORT")

dump_runpod_cache_tree() {
    echo "Contents of /runpod-volume/huggingface-cache/hub/:" >&2
    find "/runpod-volume/huggingface-cache/hub/" -maxdepth 5 \( -type f -o -type d \) 2>/dev/null | head -200 >&2 || true
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
        # Strip any stray whitespace/newlines so the resolved path stays clean.
        snapshot_hash=$(tr -d '[:space:]' < "$refs_file")
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

# Block until the rclone binary is executable. This guards against the
# "Text file busy" race that can occur when the container overlayfs has not
# yet fully exposed the binary on a freshly started serverless worker.
wait_for_rclone() {
    for i in 1 2 3 4 5; do
        if rclone version > /dev/null 2>&1; then
            echo "rclone path: $(which rclone)" >&2
            echo "rclone version: $(rclone version 2>&1 | head -2)" >&2
            return 0
        fi
        echo "Waiting for rclone to become available (attempt $i)..." >&2
        sleep 1
    done
    echo "ERROR: rclone did not become available in time" >&2
    exit 1
}

[[ -n "$RP_MODEL_PATH" ]] && SD_MODEL_PATH=$(resolve_runpod_cache_path "$RP_MODEL_PATH")
[[ -n "$RP_DIFFUSION_MODEL_PATH" ]] && SD_DIFFUSION_MODEL_PATH=$(resolve_runpod_cache_path "$RP_DIFFUSION_MODEL_PATH")
[[ -n "$RP_VAE_PATH" ]] && SD_VAE_PATH=$(resolve_runpod_cache_path "$RP_VAE_PATH")
[[ -n "$RP_LLM_PATH" ]] && SD_LLM_PATH=$(resolve_runpod_cache_path "$RP_LLM_PATH")
[[ -n "$RP_LORA_DIR" ]] && SD_LORA_DIR=$(resolve_runpod_cache_path "$RP_LORA_DIR")

# If RC_LORA_URL is set, download all LoRA files from the HTTP URL into
# /media/loras/ using rclone's :http: remote, then point SD_LORA_DIR at the
# local copy. This takes precedence over both the RP_LORA_DIR cache path
# and any direct SD_LORA_DIR setting above.
#
# Note: We use rclone copy (not mount) because RunPod serverless containers
# do not support FUSE mounts.
if [[ -n "$RC_LORA_URL" ]]; then
    echo "Downloading loras from RC_LORA_URL..."
    mkdir -p /media/loras
    wait_for_rclone
    rclone copy :http: /media/loras/ \
        --http-url "$RC_LORA_URL" \
        --transfers "${RC_TRANSFERS:-5}" \
        --retries 3 \
        --verbose
    SD_LORA_DIR=/media/loras/
fi

# If RC_LORA_S3_BUCKET is set, download all LoRA files from an S3-compatible
# endpoint into /media/loras/ using rclone's :s3: remote, then point
# SD_LORA_DIR at the local copy. This takes precedence over both the
# RP_LORA_DIR cache path and any direct SD_LORA_DIR setting above.
#
# The default provider is "Other" which works with RunPod's S3-compatible API
# (https://docs.runpod.io/storage/s3-api). Set RC_LORA_S3_PROVIDER to e.g.
# "AWS", "Minio", "Cloudflare", or "Wasabi" for other backends.
if [[ -n "$RC_LORA_S3_BUCKET" ]]; then
    echo "Downloading loras from S3-compatible storage..."
    mkdir -p /media/loras
    wait_for_rclone
    rclone copy :s3:"$RC_LORA_S3_BUCKET" /media/loras/ \
        --s3-provider "${RC_LORA_S3_PROVIDER:-Other}" \
        --s3-endpoint "$RC_LORA_S3_ENDPOINT" \
        --s3-access-key-id "$RC_LORA_S3_ACCESS_KEY_ID" \
        --s3-secret-access-key "$RC_LORA_S3_SECRET_ACCESS_KEY" \
        --s3-region "${RC_LORA_S3_REGION:-us-east-1}" \
        --s3-sign-accept-encoding=false \
        --transfers "${RC_TRANSFERS:-5}" \
        --retries 3 \
        --verbose
    SD_LORA_DIR=/media/loras/
fi

# Map each optional model/config env var to its CLI argument. Using a helper
# keeps the long block of near-identical "if set, append" checks compact.
add_arg_if_set() {
    local flag="$1"
    local value="$2"
    if [[ -n "$value" ]]; then
        SERVER_ARGS+=("$flag" "$value")
    fi
}

add_arg_if_set "--model" "$SD_MODEL_PATH"
add_arg_if_set "--clip_l" "$SD_CLIP_L_PATH"
add_arg_if_set "--clip_g" "$SD_CLIP_G_PATH"
add_arg_if_set "--t5xxl" "$SD_T5XXL_PATH"
add_arg_if_set "--llm" "$SD_LLM_PATH"
add_arg_if_set "--diffusion-model" "$SD_DIFFUSION_MODEL_PATH"
add_arg_if_set "--vae" "$SD_VAE_PATH"
add_arg_if_set "--lora-model-dir" "$SD_LORA_DIR"
add_arg_if_set "--type" "$SD_TYPE"
add_arg_if_set "--rng" "$SD_RNG"
add_arg_if_set "--threads" "$SD_THREADS"

SERVER_ARGS+=("--width" "${SD_DEFAULT_WIDTH:-1024}")
SERVER_ARGS+=("--height" "${SD_DEFAULT_HEIGHT:-1024}")
SERVER_ARGS+=("--steps" "${SD_DEFAULT_STEPS:-20}")
SERVER_ARGS+=("--cfg-scale" "${SD_DEFAULT_CFG:-7.0}")
SERVER_ARGS+=("--sampling-method" "${SD_DEFAULT_SAMPLER:-euler_a}")

# Map each "1"-valued feature flag to its bare CLI switch.
add_flag_if_enabled() {
    local var_value="$1"
    local flag="$2"
    if [[ "$var_value" == "1" ]]; then
        SERVER_ARGS+=("$flag")
    fi
}

add_flag_if_enabled "$SD_VERBOSE" "--verbose"
add_flag_if_enabled "$SD_VAE_TILING" "--vae-tiling"
add_flag_if_enabled "$SD_OFFLOAD_CPU" "--offload-to-cpu"
add_flag_if_enabled "$SD_FLASH_ATTN" "--fa"
add_flag_if_enabled "$SD_DIFFUSION_FLASH_ATTN" "--diffusion-fa"
add_flag_if_enabled "$SD_MMAP" "--mmap"
add_flag_if_enabled "$SD_CLIP_ON_CPU" "--clip-on-cpu"
add_flag_if_enabled "$SD_VAE_ON_CPU" "--vae-on-cpu"
add_flag_if_enabled "$SD_CONTROL_NET_CPU" "--control-net-cpu"
add_flag_if_enabled "${SD_DISABLE_AUTO_RESIZE_REF_IMAGE:-1}" "--disable-auto-resize-ref-image"

echo "Starting sd-server with arguments:"
echo "${SERVER_ARGS[@]}"
echo ""

sd-server "${SERVER_ARGS[@]}" &
SERVER_PID=$!

# Ensure sd-server is torn down if this script exits before handing off to the
# handler (e.g. a failed readiness check or a received signal). Once we exec
# into the handler the shell is replaced and this trap no longer applies.
trap 'kill "$SERVER_PID" 2>/dev/null || true' EXIT INT TERM

export SD_SERVER_URL="http://127.0.0.1:${SD_SERVER_PORT}"

# Defaults give 150 * 2s = 5 minutes, enough for large models (SDXL/FLUX)
# loading from a network volume on a cold start.
READY_RETRIES="${SD_READY_RETRIES:-150}"
READY_INTERVAL="${SD_READY_INTERVAL:-2}"
READY_URL="${SD_SERVER_URL}/sdapi/v1/sd-models"
LORAS_URL="${SD_SERVER_URL}/sdapi/v1/loras"

echo "Waiting for sd-server to be ready at ${READY_URL}..."
for attempt in $(seq 1 "$READY_RETRIES"); do
    if curl -sf "$READY_URL" > /dev/null 2>&1; then
        echo "sd-server is ready, initializing LoRA endpoint..."
        curl -s "$LORAS_URL" > /dev/null 2>&1 || true

        ENDPOINT_MODE="${ENDPOINT_MODE:-queue}"
        if [[ "$ENDPOINT_MODE" == "loadbalancer" ]]; then
            LB_PORT="${PORT:-80}"
            echo "Starting load-balancing handler on port ${LB_PORT}..."
            exec python -m src.handler_load_balancing
        fi

        echo "Starting queue handler..."
        exec python -m src.handler_queue
    fi

    if ! kill -0 "$SERVER_PID" 2>/dev/null; then
        echo "sd-server process died unexpectedly"
        exit 1
    fi

    if [[ "$attempt" -lt "$READY_RETRIES" ]]; then
        echo "Waiting for server... attempt ${attempt}/${READY_RETRIES}"
        sleep "$READY_INTERVAL"
    fi
done

echo "sd-server did not become ready after ${READY_RETRIES} attempts"
echo "Last checked: ${READY_URL}"
exit 1