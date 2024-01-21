ARG DEBIAN_FRONTEND=noninteractive
ARG APT_MIRROR
ARG OSXCROSS_VERSION

FROM ghcr.io/goreleaser/goreleaser-osxcross:$OSXCROSS_VERSION AS osxcross

FROM debian:bullseye AS base

ARG TARGETARCH
ARG DPKG_ARCH
ARG CROSSBUILD_ARCH
ARG OSXCROSS_PATH=/osxcross
ARG MINGW_VERSION=20230130
ARG MINGW_HOST="ubuntu-18.04"

LABEL maintainer="Artur Troian <troian dot ap at gmail dot com>"
LABEL "org.opencontainers.image.source"="https://github.com/goreleaser/goreleaser-cross-toolchains"

# Install deps
SHELL ["/bin/bash", "-c"]
RUN \
    set -x; \
    echo "Starting image build for Debian" \
 && apt-get update \
 && apt-get install --no-install-recommends -y -q \
        make \
        git-core \
        wget \
        xz-utils \
        cmake \
        openssl \
        autoconf \
        automake \
        bc \
        python \
        jq \
        binfmt-support \
        binutils-multiarch \
        build-essential \
        devscripts \
        libtool \
        llvm \
        multistrap \
        patch \
        mercurial \
        musl-tools \
 && while read arch; do dpkg --add-architecture $arch; done < <(echo "${DPKG_ARCH}" | tr ' ' '\n') \
 && crossbuild_pkgs=$(while read arch; do echo -n "crossbuild-essential-$arch "; done < <(echo "${CROSSBUILD_ARCH}" | tr ' ' '\n')) \
 && apt-get update \
 && apt-get install --no-install-recommends -y -q \
        clang \
        gcc \
        g++ \
        libarchive-tools \
        gdb \
        mingw-w64 \
        libx11-dev \
        ${crossbuild_pkgs}\
 && apt -y autoremove \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* \
    /tmp/* \
    /var/tmp/* \
 && rm -rf /usr/share/man/* \
    /usr/share/doc \
 && MINGW_ARCH=$(echo -n $TARGETARCH | sed -e 's/arm64/aarch64/g' | sed -e 's/amd64/x86_64/g') \
 && wget -qO - "https://github.com/mstorsjo/llvm-mingw/releases/download/${MINGW_VERSION}/llvm-mingw-${MINGW_VERSION}-ucrt-${MINGW_HOST}-${MINGW_ARCH}.tar.xz" | bsdtar -xf - \
 && ln -snf $(pwd)/llvm-mingw-${MINGW_VERSION}-ucrt-${MINGW_HOST}-${MINGW_ARCH} /llvm-mingw

COPY --from=osxcross "${OSXCROSS_PATH}" "${OSXCROSS_PATH}"

ENV PATH=${OSX_CROSS_PATH}/bin:$PATH
