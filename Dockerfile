FROM debian:bullseye AS toolchains-base

ENV OSX_CROSS_PATH=/osxcross
ARG DEBIAN_FRONTEND=noninteractive
ARG APT_MIRROR
ARG TARGETARCH

# Install deps
SHELL ["/bin/bash", "-c"]
RUN \
    set -x; \
    echo "Starting image build for Debian" \
 && echo "Starting image build for Debian" \
 && sed -ri "s/(httpredir|deb).debian.org/${APT_MIRROR:-deb.debian.org}/g" /etc/apt/sources.list \
 && sed -ri "s/(security).debian.org/${APT_MIRROR:-security.debian.org}/g" /etc/apt/sources.list \
 && apt-get update \
 && apt-get install --no-install-recommends -y -q \
    software-properties-common \
    curl \
    gnupg2 \
 && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1 apt-key add - \
 && echo "deb [arch=$TARGETARCH] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list \
 && apt-get update \
 && apt-get install --no-install-recommends -y -q \
    docker-ce \
    docker-ce-cli \
    make \
    git-core \
    wget \
    xz-utils \
    cmake \
    openssl \
 && dpkg --add-architecture amd64 \
 && dpkg --add-architecture arm64 \
 && dpkg --add-architecture armel \
 && dpkg --add-architecture armhf \
 && dpkg --add-architecture i386 \
 && dpkg --add-architecture mips \
 && dpkg --add-architecture mipsel \
 && dpkg --add-architecture powerpc \
 && dpkg --add-architecture ppc64el \
 && dpkg --add-architecture s390x \
 && apt-get update \
 && apt-get install --no-install-recommends -y -q \
        autoconf \
        automake \
        bc \
        python \
        jq \
        binfmt-support \
        binutils-multiarch \
        build-essential \
        clang \
        gcc \
        g++ \
        libarchive-tools \
        gdb \
        mingw-w64 \
        crossbuild-essential-amd64 \
        crossbuild-essential-arm64 \
        crossbuild-essential-armel \
        crossbuild-essential-armhf \
        crossbuild-essential-mipsel \
        crossbuild-essential-ppc64el \
        crossbuild-essential-s390x \
        devscripts \
        libtool \
        llvm \
        multistrap \
        patch \
        mercurial \
        musl-tools \
 && apt -y autoremove \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* \
    /tmp/* \
    /var/tmp/* \
    rm -rf /usr/share/man/* \
    /usr/share/doc

# install a copy of mingw with aarch64 support to enable windows on arm64
ARG TARGETARCH
ARG MINGW_VERSION=20230130
ARG MINGW_HOST="ubuntu-18.04"

RUN \
    if [ ${TARGETARCH} = "arm64" ]; then MINGW_ARCH=aarch64; elif [ ${TARGETARCH} = "amd64" ]; then MINGW_ARCH=x86_64; else echo "unsupported TARGETARCH=${TARGETARCH}"; exit 1; fi \
 && wget -qO - "https://github.com/mstorsjo/llvm-mingw/releases/download/${MINGW_VERSION}/llvm-mingw-${MINGW_VERSION}-ucrt-${MINGW_HOST}-${MINGW_ARCH}.tar.xz" | bsdtar -xf - \
 && ln -snf $(pwd)/llvm-mingw-${MINGW_VERSION}-ucrt-${MINGW_HOST}-${MINGW_ARCH} /llvm-mingw

FROM toolchains-base AS osx-cross
ARG OSX_CROSS_COMMIT
ARG OSX_SDK
ARG OSX_SDK_SUM
ARG OSX_VERSION_MIN

WORKDIR "${OSX_CROSS_PATH}"

COPY patches /patches

RUN \
    git clone https://github.com/tpoechtrager/osxcross.git . \
 && git config user.name "John Doe" \
 && git config user.email johndoe@example.com \
 && git checkout -q "${OSX_CROSS_COMMIT}" \
 && git am < /patches/libcxx.patch \
 && rm -rf ./.git

# install osxcross:
COPY tars/${OSX_SDK}.tar.xz "${OSX_CROSS_PATH}/tarballs/${OSX_SDK}.tar.xz"

RUN \
    echo "${OSX_SDK_SUM}" "${OSX_CROSS_PATH}/tarballs/${OSX_SDK}.tar.xz" | sha256sum -c - \
 && apt-get update \
 && apt-get install --no-install-recommends -y -q \
        autotools-dev \
        libxml2-dev \
        lzma-dev \
        libssl-dev \
        zlib1g-dev \
        libmpc-dev \
        libmpfr-dev \
        libgmp-dev \
        llvm-dev \
        uuid-dev \
        binutils-multiarch-dev \
 && apt -y autoremove \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
 && UNATTENDED=1 OSX_VERSION_MIN=${OSX_VERSION_MIN} ./build.sh

FROM toolchains-base AS final

LABEL maintainer="Artur Troian <troian dot ap at gmail dot com>"
LABEL "org.opencontainers.image.source"="https://github.com/goreleaser/goreleaser-cross-toolchains"

ARG DEBIAN_FRONTEND=noninteractive

COPY --from=osx-cross "${OSX_CROSS_PATH}/target" "${OSX_CROSS_PATH}/target"
ENV PATH=${OSX_CROSS_PATH}/target/bin:$PATH
