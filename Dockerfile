# ============================================================
# AlwayzPlayzZ VPS DASH
# Python + tmate client + custom tmate SSH relay server
# ============================================================


# ============================================================
# TMATE SSH SERVER BUILDER
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

# ------------------------------------------------------------
# Clone tmate SSH server
# ------------------------------------------------------------

WORKDIR /src

RUN git clone --depth 1 \
    https://github.com/tmate-io/tmate-ssh-server.git

WORKDIR /src/tmate-ssh-server


# ------------------------------------------------------------
# MessagePack compatibility
#
# Debian Trixie provides:
#
#   msgpack-c.pc
#
# but tmate's configure script looks for:
#
#   msgpack
#
# Create a compatible pkg-config alias.
# ------------------------------------------------------------

RUN set -eux; \
    echo "=========================================="; \
    echo "MESSAGEPACK PACKAGES"; \
    echo "=========================================="; \
    dpkg -l | grep msgpack || true; \
    echo ""; \
    echo "=========================================="; \
    echo "MESSAGEPACK PKGCONFIG"; \
    echo "=========================================="; \
    cat /usr/lib/x86_64-linux-gnu/pkgconfig/msgpack-c.pc; \
    echo ""; \
    mkdir -p /usr/local/lib/pkgconfig; \
    cp /usr/lib/x86_64-linux-gnu/pkgconfig/msgpack-c.pc \
        /usr/local/lib/pkgconfig/msgpack.pc; \
    sed -i 's/^Name:.*/Name: msgpack/' \
        /usr/local/lib/pkgconfig/msgpack.pc


ENV PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/lib/pkgconfig"


# ------------------------------------------------------------
# Verify MessagePack
# ------------------------------------------------------------

RUN echo "==========================================" && \
    echo "CHECKING MSGPACK" && \
    echo "==========================================" && \
    pkg-config --modversion msgpack && \
    pkg-config --cflags msgpack && \
    pkg-config --libs msgpack


# ------------------------------------------------------------
# Build tmate SSH server
# ------------------------------------------------------------

RUN ./autogen.sh && \
    ./configure \
        --prefix=/usr \
        CFLAGS="-D_GNU_SOURCE" && \
    make -j"$(nproc)" && \
    make install


# ------------------------------------------------------------
# Verify compiled relay
# ------------------------------------------------------------

RUN echo "==========================================" && \
    echo "TMATE SSH SERVER BUILD COMPLETE" && \
    echo "==========================================" && \
    command -v tmate-ssh-server && \
    ls -lh /usr/bin/tmate-ssh-server && \
    ldd /usr/bin/tmate-ssh-server


# ============================================================
# FINAL IMAGE
# ============================================================

FROM python:3.11-slim

ENV DEBIAN_FRONTEND=noninteractive


# ------------------------------------------------------------
# Runtime dependencies
#
# IMPORTANT:
# "tmate" is the CLIENT.
# "tmate-ssh-server" is the custom RELAY SERVER.
# Both are required.
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
    tmate \
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
# Verify TMATE CLIENT
# ------------------------------------------------------------

RUN echo "==========================================" && \
    echo "TMATE CLIENT CHECK" && \
    echo "==========================================" && \
    command -v tmate && \
    tmate -V && \
    echo "tmate client installed successfully"


# ------------------------------------------------------------
# Copy custom tmate SSH relay server
# ------------------------------------------------------------

COPY --from=tmate-builder \
    /usr/bin/tmate-ssh-server \
    /usr/bin/tmate-ssh-server


# ------------------------------------------------------------
# Verify TMATE RELAY SERVER
# ------------------------------------------------------------

RUN echo "==========================================" && \
    echo "TMATE SSH SERVER CHECK" && \
    echo "==========================================" && \
    ls -lh /usr/bin/tmate-ssh-server && \
    ldd /usr/bin/tmate-ssh-server


# ============================================================
# APPLICATION
# ============================================================

WORKDIR /app


# ------------------------------------------------------------
# Python requirements
# ------------------------------------------------------------

COPY requirements.txt /app/requirements.txt

RUN pip install --no-cache-dir -r /app/requirements.txt


# ------------------------------------------------------------
# Copy application
# ------------------------------------------------------------

COPY . /app


# ------------------------------------------------------------
# Dashboard compatibility
#
# dashboard_alwayzplayzz.py contains:
#
#     import bot as backend
#
# Actual backend:
#
#     vps_bot_nolxc_nodocker.py
#
# Create /app/bot.py so the dashboard can import it.
# ------------------------------------------------------------

RUN cp /app/vps_bot_nolxc_nodocker.py /app/bot.py


# ------------------------------------------------------------
# Verify application
# ------------------------------------------------------------

RUN echo "==========================================" && \
    echo "APPLICATION FILES" && \
    echo "==========================================" && \
    ls -lah /app && \
    echo "" && \
    echo "Python files:" && \
    find /app -maxdepth 2 -type f -name '*.py' -print && \
    echo "" && \
    echo "Checking required files..." && \
    test -f /app/vps_bot_nolxc_nodocker.py && \
    echo "OK: vps_bot_nolxc_nodocker.py" && \
    test -f /app/bot.py && \
    echo "OK: bot.py" && \
    test -f /app/dashboard_alwayzplayzz.py && \
    echo "OK: dashboard_alwayzplayzz.py" && \
    test -f /app/start.sh && \
    echo "OK: start.sh" && \
    echo "==========================================" && \
    echo "ALL APPLICATION FILES OK" && \
    echo "=========================================="


# ============================================================
# TMATE DIRECTORIES
# ============================================================

RUN mkdir -p /tmate/keys && \
    chmod 700 /tmate && \
    chmod 700 /tmate/keys


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
# START
# ============================================================

CMD ["/app/start.sh"]
