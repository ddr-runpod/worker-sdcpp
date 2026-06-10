ARG CUDA_VERSION=12.8.1

# RunPod Worker for stable-diffusion.cpp
#
# This image is built in two stages:
# 1. builder: clone and compile sd-server with CUDA enabled
# 2. runtime: copy only the compiled binary plus the Python worker runtime
#
# Keeping the native build in a separate stage avoids shipping compilers,
# headers, and other heavy build tools in the final production image.

FROM nvidia/cuda:${CUDA_VERSION}-cudnn-devel-ubuntu24.04 AS builder

# Pinned stable-diffusion.cpp revision for reproducible builds.
ARG SD_CPP_COMMIT=19bdfe22d255d5b4dff39d449318b9bc5ea2317f

# Repository URL is configurable to make temporary forks or mirrors easy to test.
ARG SD_CPP_REPO=https://github.com/leejet/stable-diffusion.cpp.git

# Keep apt non-interactive during Docker builds.
ENV DEBIAN_FRONTEND=noninteractive

# Native build dependencies:
# - git: clone the upstream repository
# - cmake: configure and build the project
# - build-essential: compiler and standard toolchain
# - pkg-config: native dependency discovery
# - libssl-dev / libuv1-dev: development headers and libraries required by sd-server
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    cmake \
    build-essential \
    pkg-config \
    libssl-dev \
    libuv1-dev \
    && rm -rf /var/lib/apt/lists/*

# All builder-stage work happens under /build.
WORKDIR /build

# Clone the upstream repository, fetch and check out the pinned commit, and
# initialize all required submodules.
#
# We fetch the exact commit explicitly (rather than relying on `git checkout`
# resolving it from a blobless clone). This is more robust across Git versions
# for partial clones and keeps both the main tree and submodules shallow.
RUN set -eux; \
    git clone --filter=blob:none "${SD_CPP_REPO}" stable-diffusion.cpp; \
    cd stable-diffusion.cpp; \
    git fetch --depth 1 origin "${SD_CPP_COMMIT}"; \
    git checkout "${SD_CPP_COMMIT}"; \
    git submodule update --init --recursive --depth 1

# Build sd-server with CUDA enabled.
#
# Important: CMake is invoked with -S . after changing into the repository
# so it uses the actual project root containing CMakeLists.txt.
RUN set -eux; \
    cd /build/stable-diffusion.cpp; \
    cmake -S . -B build \
        -DSD_BUILD_SERVER=ON \
        -DSD_SERVER_BUILD_FRONTEND=OFF \
        -DGGML_NATIVE=OFF \
        -DSD_CUDA=ON \
        -DCMAKE_CUDA_ARCHITECTURES="86;89;120" \
        -DCMAKE_BUILD_TYPE=Release; \
    cmake --build build --parallel "$(nproc)"; \
    test -x build/bin/sd-server

FROM nvidia/cuda:${CUDA_VERSION}-cudnn-runtime-ubuntu24.04 AS runtime

# Runtime environment:
# - VIRTUAL_ENV / PATH: isolated Python environment managed by uv
# - SD_* defaults: sensible server defaults that can still be overridden at deploy time
#
# Note: the venv bin directory comes first on PATH on purpose. The startup
# script launches the worker with `exec python ...`, and the `python` symlink
# only exists inside the venv (the base image ships `python3`). Keep it first.
ENV DEBIAN_FRONTEND=noninteractive \
    VIRTUAL_ENV=/opt/venv \
    PATH="/opt/venv/bin:/usr/local/bin:${PATH}" \
    SD_SERVER_HOST=0.0.0.0 \
    SD_SERVER_PORT=8080 \
    SD_OFFLOAD_CPU=1 \
    SD_FLASH_ATTN=1

# Runtime-only packages:
# - bash: required by the container entrypoint script
# - curl: used by readiness checks
# - libssl3 / libuv1: shared libraries needed by sd-server
# - libgomp1: GNU OpenMP runtime required by sd-server
# - python3: required to run the worker process
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    curl \
    libssl3 \
    libuv1 \
    libgomp1 \
    python3 \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install rclone at a pinned version for reproducible builds.
ARG RCLONE_VERSION=1.74.3
RUN set -eux; \
    curl -fsS "https://downloads.rclone.org/v${RCLONE_VERSION}/rclone-v${RCLONE_VERSION}-linux-amd64.zip" -o rclone.zip; \
    unzip rclone.zip; \
    cp rclone-v*/rclone /usr/bin/rclone; \
    chmod 755 /usr/bin/rclone; \
    rm -rf rclone.zip rclone-v*/; \
    echo "Installed rclone version:"; \
    unset RCLONE_VERSION; rclone version

# Copy uv from its official container image so Python dependencies can be
# installed into a dedicated virtual environment without bringing in pip tooling.
COPY --from=ghcr.io/astral-sh/uv:0.7.2 /uv /uvx /bin/

# Copy only the compiled sd-server binary from the builder stage.
COPY --from=builder /build/stable-diffusion.cpp/build/bin/sd-server /usr/local/bin/sd-server

# Copy dependency manifest first to preserve Docker layer caching when only app code changes.
COPY requirements.txt /tmp/requirements.txt

# Create the virtual environment and install Python dependencies.
#
# The final `test` asserts the venv `python` interpreter exists, since the
# startup script relies on `python` (not `python3`) being on PATH.
RUN set -eux; \
    uv venv "${VIRTUAL_ENV}"; \
    uv pip install --no-cache -r /tmp/requirements.txt; \
    rm -f /tmp/requirements.txt; \
    test -x "${VIRTUAL_ENV}/bin/python"

# Copy the worker code and the startup script.
COPY src/ /src/
COPY --chmod=755 scripts/startup.sh /scripts/startup.sh

# sd-server listens on port 8080 by default. In load-balancing mode the
# FastAPI reverse proxy listens on port 80 (RunPod's default $PORT), so
# expose both: 80 for the LB-facing proxy and 8080 for the local sd-server
# backend (and for users running queue mode and pointing clients at
# sd-server directly).
EXPOSE 80 8080

# Container-level health probe reusing the server's readiness endpoint.
# RunPod serverless ignores HEALTHCHECK, but it is useful for local runs,
# Docker Compose, and other orchestrators.
HEALTHCHECK --interval=30s --timeout=5s --start-period=120s --retries=3 \
    CMD curl -sf "http://127.0.0.1:${SD_SERVER_PORT}/sdapi/v1/sd-models" || exit 1

# The startup script launches sd-server, waits for it to become ready,
# and then starts the Python handler.
WORKDIR /
ENTRYPOINT ["/bin/bash", "/scripts/startup.sh"]