ARG OSXCROSS_VERSION="v26.1.1"

FROM ghcr.io/goreleaser/goreleaser-osxcross-musl:$OSXCROSS_VERSION AS osxcross

FROM alpine:3.22 AS musl-builder

RUN \
    apk add --no-cache \
        make \
        curl \
        bash \
        patch \
        gcc \
        g++ \
        musl-dev \
        linux-headers \
        ca-certificates \
        git \
        gawk \
        xz \
        rsync \
        file

COPY cross-make /build/cross-make

WORKDIR /build/cross-make

ARG MUSL_TARGETS

RUN set -ex; \
    for target in $MUSL_TARGETS; do \
        TARGET=$target make -j$(nproc); \
        TARGET=$target make install; \
        make clean; \
    done

FROM alpine:3.22 AS base

ARG TARGETARCH
ARG OSX_CROSS_PATH=/usr/local/osxcross

LABEL maintainer="Artur Troian <troian dot ap at gmail dot com>"
LABEL "org.opencontainers.image.source"="https://github.com/goreleaser/goreleaser-cross-toolchains"

RUN apk add --no-cache \
        make \
        git \
        wget \
        xz \
        cmake \
        openssl \
        autoconf \
        automake \
        bc \
        python3 \
        jq \
        libtool \
        llvm \
        patch \
        file

COPY --from=musl-builder "/build/cross-make/output-gcc/" "/usr/local/"

COPY --from=osxcross "${OSX_CROSS_PATH}" "${OSX_CROSS_PATH}"

WORKDIR /

ENV PATH=$PATH:"$OSX_CROSS_PATH/bin"
