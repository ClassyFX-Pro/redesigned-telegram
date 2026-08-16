# ============================================================
# AlwayzPlayzZ VPS DASH
# Python + tmate client + tmate SSH relay server
# ============================================================

FROM python:3.11-slim AS tmate-builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    autoconf \
    automake \
    build-essential \
    ca-certificates \
    cmake \
    git \
    libevent-dev \
    libmsgpack-dev \
    libncurses-dev \
    libssl-dev \
    libssh-dev \
    pkg-config \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

# Clone tmate SSH server
RUN git clone --depth 1 https://github.com/tmate-io/tmate-ssh-server.git

WORKDIR /src/tmate-ssh-server

# Debian's msgpack package may not provide the expected pkg-config
# metadata, so create the expected pkg-config file from the installed
# library/header information.
RUN set -eux; \
    MSGPACK_VERSION="$(dpkg-query -W -f='${Version}' libmsgpack-dev | sed 's/-.*//' || true)"; \
    echo "Installed msgpack package version: ${MSGPACK_VERSION}"; \
    dpkg -L libmsgpack-dev | grep -E 'libmsgpackc\.(so|a)|msgpack\.hpp|msgpack\.h' || true; \
    mkdir -p /usr/local/lib/pkgconfig; \
    LIBMSG="$(find /usr/lib /lib -name 'libmsgpackc.so' -o -name 'libmsgpackc.a' | head -1)"; \
    test -n "$LIBMSG"; \
    cat > /usr/local/lib/pkgconfig/msgpack.pc <<EOF
prefix=/usr
exec_prefix=\${prefix}
libdir=$(dirname "$LIBMSG")
includedir=/usr/include

Name: msgpack
Description: MessagePack C/C++ library
Version: 1.2.0
Libs: -lmsgpackc
Cflags: -I\${includedir}
EOF

ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/lib/pkgconfig"

RUN pkg-config --modversion msgpack

RUN ./autogen.sh \
    && ./configure \
        --prefix=/usr \
        CFLAGS="-D_GNU_SOURCE" \
    && make -j"$(nproc)" \
    && make install

# Make absolutely sure the binary exists.
RUN command -v tmate-ssh-server \
    && tmate-ssh-server --help >/dev/null 2>&1 || true


# ============================================================
# Final image
# ============================================================

FROM python:3.11-slim

ENV DEBIAN_FRONTEND=noninteractive

# Runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    passwd \
    procps \
    socat \
    sqlite3 \
    sudo \
    rsync \
    tar \
    coreutils \
    curl \
    openssh-client \
    openssh-server \
    libevent-2.1-7 \
    libmsgpackc2 \
    libncurses6 \
    libssh-4 \
    openssl \
    zlib1g \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# Copy custom tmate SSH relay server from builder
# ------------------------------------------------------------

COPY --from=tmate-builder /usr/bin/tmate-ssh-server /usr/bin/tmate-ssh-server

# Copy required runtime library if needed
COPY --from=tmate-builder /usr/local/lib/pkgconfig/msgpack.pc /usr/local/lib/pkgconfig/msgpack.pc

# Verify it REALLY exists in final image
RUN ls -lh /usr/bin/tmate-ssh-server \
    && /usr/bin/tmate-ssh-server --help >/dev/null 2>&1 || true

# ------------------------------------------------------------
# Application
# ------------------------------------------------------------

WORKDIR /app

COPY requirements.txt /app/requirements.txt

RUN pip install --no-cache-dir -r /app/requirements.txt

COPY . /app

# ------------------------------------------------------------
# tmate persistent directory
# ------------------------------------------------------------

RUN mkdir -p /tmate/keys \
    && chmod 700 /tmate \
    && chmod 700 /tmate/keys

# ------------------------------------------------------------
# Environment defaults
# ------------------------------------------------------------

ENV SSH_KEYS_PATH=/tmate/keys
ENV SSH_PORT_LISTEN=2222

# Railway public TCP hostname/port are supplied through variables.
# Do NOT hardcode them here.

# ------------------------------------------------------------
# Start
# ------------------------------------------------------------

RUN chmod +x /app/start.sh

CMD ["/app/start.sh"]
