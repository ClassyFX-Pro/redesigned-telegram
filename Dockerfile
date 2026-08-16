# ============================================================
# AlwayzPlayzZ VPS DASH
# Python + tmate client + tmate SSH relay server
# ============================================================

FROM python:3.11-slim AS tmate-builder

ENV DEBIAN_FRONTEND=noninteractive

# ------------------------------------------------------------
# Build dependencies
# ------------------------------------------------------------

RUN apt-get update && apt-get install -y --no-install-recommends \
    autoconf \
    automake \
    build-essential \
    ca-certificates \
    cmake \
    git \
    libevent-dev \
    libmsgpack-c-dev \
    libncurses-dev \
    libssl-dev \
    libssh-dev \
    pkg-config \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

# ------------------------------------------------------------
# Clone tmate SSH server
# ------------------------------------------------------------

RUN git clone --depth 1 \
    https://github.com/tmate-io/tmate-ssh-server.git

WORKDIR /src/tmate-ssh-server

# ------------------------------------------------------------
# Debian's MessagePack package uses libmsgpack-c.pc rather
# than the "msgpack.pc" name expected by tmate-ssh-server.
# Create a compatibility pkg-config file.
# ------------------------------------------------------------

RUN set -eux; \
    echo "=== MessagePack packages ==="; \
    dpkg -l | grep msgpack || true; \
    echo "=== pkg-config files ==="; \
    find /usr -name '*.pc' -type f | grep msgpack || true; \
    echo "=== MessagePack libraries ==="; \
    find /usr/lib /lib -name 'libmsgpackc.so*' -o -name 'libmsgpackc.a' || true; \
    mkdir -p /usr/local/lib/pkgconfig; \
    LIBMSG="$(find /usr/lib /lib -name 'libmsgpackc.so' -o -name 'libmsgpackc.a' | head -1)"; \
    test -n "$LIBMSG"; \
    LIBDIR="$(dirname "$LIBMSG")"; \
    cat > /usr/local/lib/pkgconfig/msgpack.pc <<EOF
prefix=/usr
exec_prefix=\${prefix}
libdir=${LIBDIR}
includedir=/usr/include

Name: msgpack
Description: MessagePack C/C++ library
Version: 1.2.0
Libs: -L\${libdir} -lmsgpackc
Cflags: -I\${includedir}
EOF

ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/lib/pkgconfig"

# ------------------------------------------------------------
# Verify MessagePack
# ------------------------------------------------------------

RUN echo "=== msgpack pkg-config ===" \
    && pkg-config --modversion msgpack \
    && pkg-config --cflags --libs msgpack

# ------------------------------------------------------------
# Build tmate SSH server
# ------------------------------------------------------------

RUN ./autogen.sh \
    && ./configure \
        --prefix=/usr \
        CFLAGS="-D_GNU_SOURCE" \
    && make -j"$(nproc)" \
    && make install

# ------------------------------------------------------------
# Verify binary
# ------------------------------------------------------------

RUN echo "=== tmate-ssh-server ===" \
    && command -v tmate-ssh-server \
    && ls -lh /usr/bin/tmate-ssh-server


# ============================================================
# Final image
# ============================================================

FROM python:3.11-slim

ENV DEBIAN_FRONTEND=noninteractive

# ------------------------------------------------------------
# Runtime dependencies
# ------------------------------------------------------------

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
    libevent-2.1-7t64 \
    libmsgpack-c2 \
    libncurses6 \
    libssh-4 \
    openssl \
    zlib1g \
    && rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------
# Copy tmate SSH relay server
# ------------------------------------------------------------

COPY --from=tmate-builder \
    /usr/bin/tmate-ssh-server \
    /usr/bin/tmate-ssh-server

# ------------------------------------------------------------
# Verify tmate binary exists
# ------------------------------------------------------------

RUN echo "=== FINAL IMAGE: tmate-ssh-server ===" \
    && ls -lh /usr/bin/tmate-ssh-server \
    && /usr/bin/tmate-ssh-server --help >/dev/null 2>&1 || true

# ============================================================
# Application
# ============================================================

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

# ------------------------------------------------------------
# Start
# ------------------------------------------------------------

RUN chmod +x /app/start.sh

CMD ["/app/start.sh"]
