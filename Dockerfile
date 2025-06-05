FROM ghcr.io/ggml-org/llama.cpp:full-cuda-b5590

# Author label
LABEL maintainer="Yucheng Zhang <Yucheng.Zhang@tufts.edu>"

ENV PATH="/app:${PATH}"