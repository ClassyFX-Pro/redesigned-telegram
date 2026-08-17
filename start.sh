```sh
#!/bin/sh
set -eu

echo "=========================================="
echo "   AlwayzPlayzZ VPS DASH - STARTING"
echo "   Discord Bot + Dashboard + tmate Relay"
echo "=========================================="

# ============================================================
# CONFIGURATION
# ============================================================

TMATE_KEYS="${SSH_KEYS_PATH:-/tmate/keys}"
TMATE_PORT="${SSH_PORT_LISTEN:-2222}"
TMATE_PUBLIC_HOST="${TMATE_SERVER_HOST:-sakura.proxy.rlwy.net}"
TMATE_PUBLIC_PORT="${TMATE_SERVER_PORT:-53743}"

echo "[TMATE] Key directory: $TMATE_KEYS"
echo "[TMATE] Listen port: $TMATE_PORT"
echo "[TMATE] Public host: $TMATE_PUBLIC_HOST"
echo "[TMATE] Public port: $TMATE_PUBLIC_PORT"

# ============================================================
# CREATE TMATE DIRECTORIES
# ============================================================

mkdir -p "$TMATE_KEYS"
chmod 700 "$TMATE_KEYS"

# ============================================================
# GENERATE TMATE SSH HOST KEYS
# ============================================================

if [ ! -f "$TMATE_KEYS/ssh_host_rsa_key" ]; then
    echo "[TMATE] Generating RSA host key..."

    ssh-keygen \
        -t rsa \
        -b 4096 \
        -f "$TMATE_KEYS/ssh_host_rsa_key" \
        -N ""
fi

if [ ! -f "$TMATE_KEYS/ssh_host_ed25519_key" ]; then
    echo "[TMATE] Generating ED25519 host key..."

    ssh-keygen \
        -t ed25519 \
        -f "$TMATE_KEYS/ssh_host_ed25519_key" \
        -N ""
fi

chmod 600 "$TMATE_KEYS"/ssh_host_*_key 2>/dev/null || true

echo "[TMATE] Host keys ready."

# ============================================================
# CHECK TMATE SSH SERVER
# ============================================================

if [ ! -x /usr/bin/tmate-ssh-server ]; then
    echo "[TMATE] ERROR: /usr/bin/tmate-ssh-server does not exist."
    exit 1
fi

echo "[TMATE] tmate-ssh-server found:"
ls -lh /usr/bin/tmate-ssh-server

# ============================================================
# START TMATE SSH RELAY
# ============================================================

echo "[TMATE] Starting tmate-ssh-server..."

rm -f /tmp/tmate-relay.log

/usr/bin/tmate-ssh-server \
    -p "$TMATE_PORT" \
    -q "$TMATE_PUBLIC_PORT" \
    -h "$TMATE_PUBLIC_HOST" \
    -k "$TMATE_KEYS" \
    > /tmp/tmate-relay.log 2>&1 &

TMATE_PID=$!

echo "[TMATE] Relay PID: $TMATE_PID"

# ============================================================
# WAIT FOR TMATE RELAY
# ============================================================

sleep 2

if ! kill -0 "$TMATE_PID" 2>/dev/null; then
    echo "[TMATE] =========================================="
    echo "[TMATE] ERROR: Relay failed to start"
    echo "[TMATE] =========================================="
    cat /tmp/tmate-relay.log 2>/dev/null || true
    exit 1
fi

echo "[TMATE] Relay started successfully."

if command -v ss >/dev/null 2>&1; then
    echo "[TMATE] Listening sockets:"
    ss -lntp 2>/dev/null | grep ":$TMATE_PORT " || \
        echo "[TMATE] WARNING: Port $TMATE_PORT not visible yet."
fi

# ============================================================
# START DISCORD BOT
# ============================================================

echo "=========================================="
echo "[START] Starting Discord bot..."
echo "[START] /app/vps_bot_nolxc_nodocker.py"
echo "=========================================="

if [ ! -f /app/vps_bot_nolxc_nodocker.py ]; then
    echo "[ERROR] Bot file does not exist:"
    echo "/app/vps_bot_nolxc_nodocker.py"

    echo "[ERROR] Available Python files:"
    find /app -maxdepth 3 -type f -name "*.py" -print

    exit 1
fi

python -u /app/vps_bot_nolxc_nodocker.py &
BOT_PID=$!

echo "[START] BOT PID: $BOT_PID"

sleep 2

if ! kill -0 "$BOT_PID" 2>/dev/null; then
    echo "[ERROR] Bot exited immediately."

    if [ -f /tmp/tmate-relay.log ]; then
        echo "[TMATE] Relay log:"
        cat /tmp/tmate-relay.log || true
    fi

    exit 1
fi

# ============================================================
# START DASHBOARD
# ============================================================

echo "=========================================="
echo "[START] Starting dashboard..."
echo "[START] /app/dashboard_alwayzplayzz.py"
echo "=========================================="

if [ ! -f /app/dashboard_alwayzplayzz.py ]; then
    echo "[ERROR] Dashboard file does not exist:"
    echo "/app/dashboard_alwayzplayzz.py"
    exit 1
fi

python -u /app/dashboard_alwayzplayzz.py &
DASH_PID=$!

echo "[START] DASHBOARD PID: $DASH_PID"

sleep 2

if ! kill -0 "$DASH_PID" 2>/dev/null; then
    echo "[ERROR] Dashboard exited immediately."
    exit 1
fi

# ============================================================
# SERVICES STARTED
# ============================================================

echo ""
echo "=========================================="
echo "   ALL SERVICES STARTED"
echo "=========================================="
echo "[START] BOT PID:       $BOT_PID"
echo "[START] DASHBOARD PID: $DASH_PID"
echo "[START] TMATE PID:     $TMATE_PID"
echo "[START] TMATE PORT:    $TMATE_PORT"
echo "[START] TMATE PUBLIC:  $TMATE_PUBLIC_HOST:$TMATE_PUBLIC_PORT"
echo "=========================================="
echo ""

# ============================================================
# CLEANUP
# ============================================================

cleanup() {
    echo ""
    echo "=========================================="
    echo "   SHUTTING DOWN"
    echo "=========================================="

    if kill -0 "$BOT_PID" 2>/dev/null; then
        echo "[STOP] Stopping bot..."
        kill "$BOT_PID" 2>/dev/null || true
    fi

    if kill -0 "$DASH_PID" 2>/dev/null; then
        echo "[STOP] Stopping dashboard..."
        kill "$DASH_PID" 2>/dev/null || true
    fi

    if kill -0 "$TMATE_PID" 2>/dev/null; then
        echo "[STOP] Stopping tmate relay..."
        kill "$TMATE_PID" 2>/dev/null || true
    fi

    wait "$BOT_PID" 2>/dev/null || true
    wait "$DASH_PID" 2>/dev/null || true
    wait "$TMATE_PID" 2>/dev/null || true

    echo "[STOP] Shutdown complete."
}

trap cleanup INT TERM EXIT

# ============================================================
# MONITOR SERVICES
# ============================================================

while true; do

    # --------------------------------------------------------
    # BOT
    # --------------------------------------------------------

    if ! kill -0 "$BOT_PID" 2>/dev/null; then
        echo "[ERROR] Discord bot exited."
        cleanup
        exit 1
    fi

    # --------------------------------------------------------
    # DASHBOARD
    # --------------------------------------------------------

    if ! kill -0 "$DASH_PID" 2>/dev/null; then
        echo "[ERROR] Dashboard exited."
        cleanup
        exit 1
    fi

    # --------------------------------------------------------
    # TMATE
    # --------------------------------------------------------

    if ! kill -0 "$TMATE_PID" 2>/dev/null; then
        echo "[ERROR] tmate-ssh-server exited."

        echo ""
        echo "========== TMATE LOG =========="
        cat /tmp/tmate-relay.log 2>/dev/null || true
        echo "==============================="

        cleanup
        exit 1
    fi

    sleep 5

done
```
