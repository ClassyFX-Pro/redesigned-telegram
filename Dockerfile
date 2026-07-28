FROM python:3.11-slim

# Runtime tools required by the VPS backend
RUN apt-get update && apt-get install -y --no-install-recommends \
    passwd procps socat sqlite3 sudo rsync tar coreutils curl \
    && rm -rf /var/lib/apt/lists/*

# Web terminal gateway
RUN curl -fsSL -o /usr/local/bin/ttyd \
    https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.x86_64 \
    && chmod +x /usr/local/bin/ttyd

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Bot
COPY vps_bot_nolxc_nodocker.py bot.py

# SSH/web-terminal gateway
COPY ssh_gateway.sh /app/ssh_gateway.sh
RUN chmod +x /app/ssh_gateway.sh

# Animated AlwayzPlayzZ dashboard
COPY dashboard_alwayzplayzz.py /app/dashboard.py

# Start both services so Railway logs show bot.py and the dashboard.
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

# Railway can expose the dashboard through its TCP proxy on 2026.
EXPOSE 2026

CMD ["/app/start.sh"]
