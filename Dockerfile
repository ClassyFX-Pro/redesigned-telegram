FROM python:3.11-slim AS tmate-builder

# ============================================================
# Build tmate-ssh-server
# ============================================================

RUN apt-get update && apt-get install -y --no-install-recommends \
    autoconf \
    automake \
    cmake \
    g++ \
    gcc \
    git \
    libevent-dev \
    libmsgpack-c-dev \
    libncurses-dev \
    libssl-dev \
    libssh-dev \
    linux-libc-dev \
    make \
    pkg-config \
    zlib1g-dev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src/tmate-ssh-server

RUN git clone --depth 1 https://github.com/tmate-io/tmate-ssh-server.git .

# Verify MessagePack is actually visible to pkg-config
RUN pkg-config --modversion msgpack

RUN ./autogen.sh \
    && ./configure \
        --prefix=/usr \
        CFLAGS="-D_GNU_SOURCE" \
    && make -j"$(nproc)" \
    && make install


# ============================================================
# Runtime image
# ============================================================

FROM python:3.11-slim

# ============================================================
# Runtime tools required by VPS backend + tmate relay
# ============================================================

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
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*


# ============================================================
# Copy compiled tmate SSH relay
# ============================================================

COPY --from=tmate-builder /usr/bin/tmate-ssh-server /usr/bin/tmate-ssh-server


# ============================================================
# Application
# ============================================================

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

# Bot
COPY vps_bot_nolxc_nodocker.py /app/bot.py

# Dashboard
COPY dashboard_alwayzplayzz.py /app/dashboard.py

# Startup script
COPY start.sh /app/start.sh

RUN chmod +x /app/start.sh


# ============================================================
# Railway ports
# ============================================================

# Dashboard
EXPOSE 2026

# Internal tmate relay
EXPOSE 2222

# ============================================================
# Start everything
# ============================================================

CMD ["/app/start.sh"]
