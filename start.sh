# ============================================================
# BUILD TMATE SSH RELAY
# ============================================================

FROM python:3.11-slim AS tmate-builder

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
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src/tmate-ssh-server

RUN git clone --depth 1 https://github.com/tmate-io/tmate-ssh-server.git .

RUN ./autogen.sh \
    && ./configure \
        --prefix=/usr \
        CFLAGS="-D_GNU_SOURCE" \
    && make -j"$(nproc)" \
    && make install


# ============================================================
# RUNTIME
# ============================================================

FROM python:3.11-slim

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


# Copy compiled relay
COPY --from=tmate-builder /usr/bin/tmate-ssh-server /usr/bin/tmate-ssh-server


# ============================================================
# BOT
# ============================================================

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY vps_bot_nolxc_nodocker.py /app/bot.py

COPY dashboard_alwayzplayzz.py /app/dashboard.py

COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh


# ============================================================
# RAILWAY PORTS
# ============================================================

EXPOSE 2026
EXPOSE 2222


# ============================================================
# START
# ============================================================

CMD ["/app/start.sh"]
