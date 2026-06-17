# syntax=docker/dockerfile:1
############################
# Builder stage
############################
FROM debian:trixie-slim AS builder
ENV DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-lc"]
# Install OCaml + build tools
RUN set -euxo pipefail && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
      ca-certificates \
      curl \
      git \
      make \
      gcc \
      g++ \
      binutils \
      m4 \
      pkg-config \
      libgc-dev \
      bubblewrap \
      unzip \
      python3 \
      python3-markdown \
      ocaml \
      ocamlbuild && \
    rm -rf /var/lib/apt/lists/*
WORKDIR /src
# Clone and build AWE
RUN set -euxo pipefail && \
    git clone https://github.com/glynawe/awe.git . && \
    make clean && make && make install
# Ensure the static archive has an index
RUN set -euxo pipefail && \
    test -f /usr/local/lib/libawe.a && \
    ranlib /usr/local/lib/libawe.a
# Verify expected files installed
RUN set -euxo pipefail && \
    test -x /usr/local/bin/awe && \
    test -f /usr/local/include/awe.h && \
    test -f /usr/local/include/aweio.h && \
    test -f /usr/local/include/awe.mk && \
    test -f /usr/local/lib/libawe.a && \
    test -f /usr/local/share/doc/awe/awe.html && \
    test -f /usr/local/share/man/man1/awe.1 && \
    test -f /usr/local/share/man/man7/awe.mk.7
############################
# Runtime stage
############################
FROM debian:trixie-slim
ENV DEBIAN_FRONTEND=noninteractive
# We need gcc/binutils to build generated C code
RUN set -euxo pipefail && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
      ocaml-nox \
      gcc \
      binutils \
      libgc1 \
      libgc-dev \
      libstdc++6 && \
    rm -rf /var/lib/apt/lists/*
# Copy built artifacts
COPY --from=builder /usr/local/ /usr/local/
# ======================================================
# Ensure ld treats /usr/local/lib first for static libs
# ======================================================
ENV LIBRARY_PATH=/usr/local/lib
WORKDIR /work
ENTRYPOINT ["/usr/local/bin/awe"]
