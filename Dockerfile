FROM python:3.11-slim

# passwd = useradd/userdel/su/passwd, procps = ps/pgrep, socat = port forwarding,
# sqlite3 = CLI used by the gateway script to validate one-time access
# codes, rsync = clone-vps, curl = fetch the ttyd binary below
RUN apt-get update && apt-get install -y --no-install-recommends \
    passwd procps socat sqlite3 sudo rsync tar coreutils curl \
    && rm -rf /var/lib/apt/lists/*

# ttyd = web terminal gateway (replaces tmate - tmate needs an outbound
# connection to a relay server that Railway blocks; ttyd only needs
# Railway's normal inbound public port, which it already supports).
# Not reliably available via apt on debian slim, so grab the static binary.
RUN curl -fsSL -o /usr/local/bin/ttyd \
    https://github.com/tsl0922/ttyd/releases/latest/download/ttyd.x86_64 \
    && chmod +x /usr/local/bin/ttyd

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY vps_bot_nolxc_nodocker.py bot.py
COPY ssh_gateway.sh /app/ssh_gateway.sh
RUN chmod +x /app/ssh_gateway.sh

# Railway runs this container as root already (confirmed in your setup) -
# useradd/su need that, so we do NOT drop to a non-root user here.
CMD ["python", "bot.py"]
