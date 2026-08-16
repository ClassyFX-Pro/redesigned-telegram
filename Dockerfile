# ============================================================
# STAGE 1 — Build tmate-ssh-server
# ============================================================

FROM python:3.11-slim AS tmate-builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    autoconf \
    automake \
    build-essential \
    ca-certificates \
    cmake \
    git \
    libevent-dev \
    libncurses-dev \
    libssl-dev \
    libssh-dev \
    linux-libc-dev \
    pkg-config \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Build MessagePack ourselves so msgpack.pc definitely exists.
WORKDIR /tmp/msgpack

RUN git clone --depth 1 --branch cpp-7.1.0 \
    https://github.com/msgpack/msgpack-c.git .

RUN cmake -S . -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DMSGPACK_BUILD_TESTS=OFF \
    -DMSGPACK_BUILD_EXAMPLES=OFF \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    && cmake --build build -j"$(nproc)" \
    && cmake --install build

# Make pkg-config find the MessagePack installation.
ENV PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:/usr/local/share/pkgconfig:$PKG_CONFIG_PATH

# Verify that the dependency REALLY exists before compiling tmate.
RUN find /usr/local -name 'msgpack.pc' -print

RUN pkg-config --modversion msgpack

# ============================================================
# Build tmate SSH server
# ============================================================

WORKDIR /src/tmate-ssh-server

RUN git clone --depth 1 \
    https://github.com/tmate-io/tmate-ssh-server.git .

RUN ./autogen.sh \
    && ./configure \
        --prefix=/usr/local \
        CFLAGS="-D_GNU_SOURCE -I/usr/local/include" \
        LDFLAGS="-L/usr/local/lib" \
    && make -j"$(nproc)" \
    && make install

# Verify binary exists.
RUN which tmate-ssh-server \
    && tmate-ssh-server --help || true


# ============================================================
# STAGE 2 — Runtime
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
    iproute2 \
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

# ============================================================
# Copy tmate relay
# ============================================================

COPY --from=tmate-builder /usr/local/bin/tmate-ssh-server /usr/local/bin/tmate-ssh-server

# Copy any libraries installed by the builder.
COPY --from=tmate-builder /usr/local/lib/ /usr/local/lib/

RUN ldconfig

# Verify it exists in FINAL image.
RUN which tmate-ssh-server \
    && tmate-ssh-server --help || true


# ============================================================
# Application
# ============================================================

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY vps_bot_nolxc_nodocker.py /app/bot.py

COPY dashboard_alwayzplayzz.py /app/dashboard.py

COPY start.sh /app/start.sh

RUN chmod +x /app/start.sh


# ============================================================
# Railway ports
# ============================================================

EXPOSE 2026
EXPOSE 2222

CMD ["/app/start.sh"]
