FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

# Install Python and required tools
RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    python-is-python3 \
    passwd \
    procps \
    socat \
    sqlite3 \
    sudo \
    rsync \
    tar \
    coreutils \
    curl \
    ca-certificates \
    bash \
    openssh-client \
    util-linux \
    wget \
    git \
    unzip \
    nano \
    vim \
    htop \
    && rm -rf /var/lib/apt/lists/*

# Install ttyd
RUN curl -fsSL \
    -o /usr/local/bin/ttyd \
    https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.x86_64 \
    && chmod +x /usr/local/bin/ttyd

WORKDIR /app

COPY requirements.txt .

RUN python -m pip install --break-system-packages --no-cache-dir -r requirements.txt

# Copy application
COPY vps_bot_nolxc_nodocker.py /app/bot.py
COPY dashboard_alwayzplayzz.py /app/dashboard.py
COPY ssh_gateway.sh /app/ssh_gateway.sh
COPY start.sh /app/start.sh

RUN chmod +x /app/start.sh /app/ssh_gateway.sh

EXPOSE 2026

CMD ["/app/start.sh"]
