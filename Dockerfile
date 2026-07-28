FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

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
    git \
    wget \
    unzip \
    nano \
    vim \
    htop \
    && rm -rf /var/lib/apt/lists/*

RUN curl -L \
https://github.com/tsl0922/ttyd/releases/download/1.7.7/ttyd.x86_64 \
-o /usr/local/bin/ttyd && chmod +x /usr/local/bin/ttyd

WORKDIR /app

COPY requirements.txt .
RUN pip3 install --break-system-packages --no-cache-dir -r requirements.txt

COPY vps_bot_nolxc_nodocker.py bot.py
COPY dashboard_alwayzplayzz.py dashboard.py
COPY ssh_gateway.sh .
COPY start.sh .

RUN chmod +x start.sh ssh_gateway.sh

EXPOSE 2026

CMD ["./start.sh"]
