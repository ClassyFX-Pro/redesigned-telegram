FROM python:3.11-slim

# passwd = useradd/userdel/su/passwd, procps = ps/pgrep, socat = port forwarding,
# tmate = SSH-like sessions, sudo = just in case, rsync = used by clone-vps
RUN apt-get update && apt-get install -y --no-install-recommends \
    passwd procps socat tmate sudo rsync tar coreutils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY vps_bot_nolxc_nodocker.py bot.py

# Railway runs this container as root already (confirmed in your setup) -
# useradd/su need that, so we do NOT drop to a non-root user here.
CMD ["python", "bot.py"]
