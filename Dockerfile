# RunPod Worker for stable-diffusion.cpp
# Multi-stage build: build sd-server, then package for RunPod

FROM nvidia/cuda:12.6.3-cudnn-devel-ubuntu24.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive
ENV MAKEFLAGS="-j$(nproc)"

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    cmake \
    build-essential \
    pkg-config \
    libssl-dev \
    libuv-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN git clone --depth 1 https://github.com/leejet/stable-diffusion.cpp.git

WORKDIR /build/stable-diffusion.cpp

RUN git submodule update --init --recursive

RUN cmake -B build \
    -DSD_BUILD_SERVER=ON \
    -DSD_SERVER_BUILD_FRONTEND=OFF \
    -DSD_CUBLAS=ON \
    -DCMAKE_BUILD_TYPE=Release

RUN cmake --build build --config Release --parallel

FROM nvidia/cuda:12.6.3-cudnn-runtime-ubuntu24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl3 \
    libuv1 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /build/stable-diffusion.cpp/build/sd-server /usr/local/bin/

RUN mkdir -p /scripts

COPY scripts/startup.sh /scripts/startup.sh
RUN chmod +x /scripts/startup.sh

ENV SD_SERVER_HOST=0.0.0.0
ENV SD_SERVER_PORT=8080
ENV SD_LORA_DIR=/models
ENV SD_RNG=cuda
ENV SD_THREADS=-1
ENV SD_DEFAULT_WIDTH=512
ENV SD_DEFAULT_HEIGHT=512
ENV SD_DEFAULT_STEPS=20
ENV SD_DEFAULT_CFG=7.0
ENV SD_DEFAULT_SAMPLER=euler_a

EXPOSE 8080

WORKDIR /

ENTRYPOINT ["/bin/bash", "/scripts/startup.sh"]
