ARG UBUNTU_VERSION=22.04
# This needs to generally match the container host's environment.
ARG CUDA_VERSION=12.2.0 # Changed to 12.2.0
# Target the CUDA build image
ARG BASE_CUDA_DEV_CONTAINER=nvidia/cuda:${CUDA_VERSION}-devel-ubuntu${UBUNTU_VERSION}

FROM ${BASE_CUDA_DEV_CONTAINER}

# Add environment variables to PATH and LD_LIBRARY_PATH
ENV PATH="/app:${PATH}"
ENV LD_LIBRARY_PATH="/app:${LD_LIBRARY_PATH}"

# CUDA architecture to build for (defaults to all supported archs)
ARG CUDA_DOCKER_ARCH=default

# Install all necessary packages for building and running
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    python3 \
    python3-pip \
    git \
    libcurl4-openssl-dev \
    libgomp1 \
    curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY . .

# Build llama.cpp
RUN if [ "${CUDA_DOCKER_ARCH}" != "default" ]; then \
    export CMAKE_ARGS="-DCMAKE_CUDA_ARCHITECTURES=${CUDA_DOCKER_ARCH}"; \
    fi && \
    cmake -B build -DGGML_NATIVE=OFF -DGGML_CUDA=ON -DGGML_BACKEND_DL=ON -DGGML_CPU_ALL_VARIANTS=ON -DLLAMA_BUILD_TESTS=OFF ${CMAKE_ARGS} -DCMAKE_EXE_LINKER_FLAGS=-Wl,--allow-shlib-undefined . && \
    cmake --build build --config Release -j$(nproc)

# Copy built binaries and shared libraries directly to /app
RUN cp build/bin/* /app/ && \
    find build -name "*.so" -exec cp {} /app \;

# Copy Python scripts and requirements
RUN cp *.py /app/ && \
    cp -r gguf-py /app/ && \
    cp -r requirements /app/ && \
    cp requirements.txt /app/ && \
    cp .devops/tools.sh /app/tools.sh

# Install Python dependencies
RUN pip install --upgrade pip setuptools wheel && \
    pip install -r requirements.txt

# Final cleanup of temporary files and caches
RUN apt-get autoremove -y && \
    apt-get clean -y && \
    rm -rf /tmp/* /var/tmp/* && \
    find /var/cache/apt/archives /var/lib/apt/lists -not -name lock -type f -delete && \
    find /var/cache -type f -delete

WORKDIR /app

ENTRYPOINT ["/app/tools.sh"]
