# ============================================================
# Stage 1: Build the official tmate SSH relay
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
    libmsgpack-dev \
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
    && ./configure --prefix=/usr CFLAGS="-D_GNU_SOURCE" \
    && make -j"$(nproc)" \
    && make install


# ============================================================
# Stage 2: Bot + dashboard + tmate relay
# ============================================================
FROM python:3.11-slim

ENV DEBIAN_FRONTEND=noninteractive

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
    libevent-2.1-7t64 \
    libmsgpack-c2 \
    libncurses6 \
    libssh-4 \
    openssl \
    zlib1g \
    && rm -rf /var/lib/apt/lists/*

# Official tmate SSH relay binary
COPY --from=tmate-builder /usr/bin/tmate-ssh-server /usr/bin/tmate-ssh-server

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Bot
COPY vps_bot_nolxc_nodocker.py bot.py

# Dashboard
COPY dashboard_alwayzplayzz.py /app/dashboard.py

# Startup script
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

# tmate relay
EXPOSE 2222

# Dashboard
EXPOSE 2026

CMD ["/app/start.sh"]
