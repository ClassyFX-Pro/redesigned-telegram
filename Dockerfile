# ============================================================
# AlwayzPlayzZ VPS DASH
# Python 3.11 + tmate client + custom tmate SSH relay server
# ============================================================

# ============================================================
# STAGE 1 — BUILD TMATE SSH SERVER
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
    https://github.com/tmate-io/tmate-ssh-server.git \
    tmate-ssh-server

WORKDIR /src/tmate-ssh-server

# ------------------------------------------------------------
# Debian provides msgpack-c.pc rather than msgpack.pc.
# tmate's configure script expects "msgpack".
# Create a compatible pkg-config alias.
# ------------------------------------------------------------

RUN set -eux; \
    echo "==========================================" ; \
    echo "MESSAGEPACK PACKAGES" ; \
    echo "==========================================" ; \
    dpkg -l | grep msgpack || true ; \
    echo "" ; \
    echo "==========================================" ; \
    echo "MESSAGEPACK PKGCONFIG" ; \
    echo "==========================================" ; \
    cat /usr/lib/x86_64-linux-gnu/pkgconfig/msgpack-c.pc ; \
    mkdir -p /usr/local/lib/pkgconfig ; \
    cp \
        /usr/lib/x86_64-linux-gnu/pkgconfig/msgpack-c.pc \
        /usr/local/lib/pkgconfig/msgpack.pc ; \
    sed -i 's/^Name: .*/Name: msgpack/' \
        /usr/local/lib/pkgconfig/msgpack.pc

ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/lib/pkgconfig"

# ------------------------------------------------------------
# Verify MessagePack
# ------------------------------------------------------------

RUN echo "==========================================" \
    && echo "CHECKING MSGPACK" \
    && echo "==========================================" \
    && pkg-config --modversion msgpack \
    && pkg-config --cflags msgpack \
    && pkg-config --libs msgpack

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
# Verify build
# ------------------------------------------------------------

RUN echo "==========================================" \
    && echo "TMATE SSH SERVER BUILD COMPLETE" \
    && echo "==========================================" \
    && command -v tmate-ssh-server \
    && ls -lh /usr/bin/tmate-ssh-server


# ============================================================
# STAGE 2 — FINAL APPLICATION IMAGE
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
# Copy custom tmate SSH relay server
# ------------------------------------------------------------

COPY --from=tmate-builder \
    /usr/bin/tmate-ssh-server \
    /usr/bin/tmate-ssh-server

# ------------------------------------------------------------
# Verify tmate binary and libraries
# ------------------------------------------------------------

RUN echo "==========================================" \
    && echo "FINAL TMATE CHECK" \
    && echo "==========================================" \
    && ls -lh /usr/bin/tmate-ssh-server \
    && ldd /usr/bin/tmate-ssh-server \
    && /usr/bin/tmate-ssh-server --help >/dev/null 2>&1 || true


# ============================================================
# APPLICATION
# ============================================================

WORKDIR /app

# ------------------------------------------------------------
# Python dependencies
# ------------------------------------------------------------

COPY requirements.txt /app/requirements.txt

RUN pip install --no-cache-dir -r /app/requirements.txt

# ------------------------------------------------------------
# Copy application
# ------------------------------------------------------------

COPY . /app

# ------------------------------------------------------------
# Verify application files
# ------------------------------------------------------------

RUN echo "==========================================" \
    && echo "APPLICATION FILES" \
    && echo "==========================================" \
    && ls -la /app \
    && echo "" \
    && echo "Python files:" \
    && find /app -maxdepth 3 -type f -name "*.py" -print \
    && echo "" \
    && echo "Checking VPS bot..." \
    && test -f /app/vps_bot_nolxc_nodocker.py \
    && echo "SUCCESS: VPS bot exists" \
    && echo "" \
    && echo "Checking dashboard..." \
    && test -f /app/dashboard_alwayzplayzz.py \
    && echo "SUCCESS: Dashboard exists" \
    && echo "" \
    && echo "Checking start.sh..." \
    && test -f /app/start.sh \
    && echo "SUCCESS: start.sh exists"

# ============================================================
# TMATE STORAGE
# ============================================================

RUN mkdir -p /tmate/keys \
    && chmod 700 /tmate \
    && chmod 700 /tmate/keys

# ============================================================
# ENVIRONMENT
# ============================================================

ENV SSH_KEYS_PATH=/tmate/keys
ENV SSH_PORT_LISTEN=2222

# ============================================================
# START SCRIPT
# ============================================================

RUN chmod +x /app/start.sh

# ============================================================
# START CONTAINER
# ============================================================

CMD ["/app/start.sh"]
