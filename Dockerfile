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
# Stage 2: Your bot + dashboard + tmate relay
# ============================================================
FROM python:3.11-slim

ENV DEBIAN_FRONTEND=noninteractive

# Runtime tools required by the VPS backend + tmate client
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
    libevent-2.1-7 \
    libmsgpackc2 \
    libncurses6 \
    libssh-4 \
    openssl \
    zlib1g \
    && rm -rf /var/lib/apt/lists/*

# Copy the compiled OFFICIAL tmate relay
COPY --from=tmate-builder /usr/bin/tmate-ssh-server /usr/bin/tmate-ssh-server

WORKDIR /app

# Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Bot
COPY vps_bot_nolxc_nodocker.py bot.py

# Animated AlwayzPlayzZ dashboard
COPY dashboard_alwayzplayzz.py /app/dashboard.py

# Combined startup script
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

# tmate relay internal listener
EXPOSE 2222

# Dashboard
EXPOSE 2026

CMD ["/app/start.sh"]
