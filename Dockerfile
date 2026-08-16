FROM python:3.11-slim

# ============================================================
# SYSTEM PACKAGES
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
    netcat-openbsd \
    iproute2 \
    && rm -rf /var/lib/apt/lists/*


# ============================================================
# APPLICATION
# ============================================================

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

# Discord bot
COPY vps_bot_nolxc_nodocker.py /app/bot.py

# Dashboard
COPY dashboard_alwayzplayzz.py /app/dashboard.py

# Startup script
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
