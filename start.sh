#!/bin/sh

set -eu

echo "=========================================="
echo "   AlwayzPlayzZ VPS DASH - STARTING"
echo "   Discord Bot + Dashboard + tmate Relay"
echo "=========================================="

# ============================================================
# Configuration
# ============================================================

TMATE_KEYS="${SSH_KEYS_PATH:-/tmate/keys}"
TMATE_PORT="${SSH_PORT_LISTEN:-2222}"

echo "[TMATE] Key directory: $TMATE_KEYS"
echo "[TMATE] Listen port: $TMATE_PORT"

# ============================================================
# Prepare tmate keys
# ============================================================

mkdir -p "$TMATE_KEYS"

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
# Verify tmate binary
# ============================================================

if [ ! -x /usr/bin/tmate-ssh-server ]; then
    echo "[TMATE] =========================================="
    echo "[TMATE] ERROR: /usr/bin/tmate-ssh-server missing"
    echo "[TMATE] =========================================="
    exit 1
fi

echo "[TMATE] tmate-ssh-server found."

# ============================================================
# Start tmate SSH relay
# ============================================================

echo "[TMATE] Starting tmate-ssh-server..."

/usr/bin/tmate-ssh-server \
    -p "$TMATE_PORT" \
    -k "$TMATE_KEYS" \
    > /tmp/tmate-relay.log 2>&1 &

TMATE_PID=$!

echo "[TMATE] Relay PID: $TMATE_PID"

sleep 3

# ============================================================
# Check relay
# ============================================================

if ! kill -0 "$TMATE_PID" 2>/dev/null; then

    echo "[TMATE] =========================================="
    echo "[TMATE] ERROR: Relay failed to start"
    echo "[TMATE] =========================================="

    cat /tmp/tmate-relay.log 2>/dev/null || true

    exit 1
fi

echo "[TMATE] Relay started successfully."

# ============================================================
# Verify port
# ============================================================

if command -v ss >/dev/null 2>&1; then
    echo "[TMATE] Listening sockets:"
    ss -lntp 2>/dev/null | grep ":$TMATE_PORT " || true
fi

# ============================================================
# Verify bot
# ============================================================

echo "[BOT] Checking /app/bot.py..."

if [ ! -f /app/bot.py ]; then
    echo "[BOT] =========================================="
    echo "[BOT] ERROR: /app/bot.py does not exist"
    echo "[BOT] =========================================="
    echo "[BOT] Contents of /app:"
    ls -la /app
    exit 1
fi

echo "[BOT] /app/bot.py found."

# ============================================================
# Verify dashboard
# ============================================================

if [ ! -f /app/dashboard.py ]; then
    echo "[DASHBOARD] =========================================="
    echo "[DASHBOARD] ERROR: /app/dashboard.py does not exist"
    echo "[DASHBOARD] =========================================="
    ls -la /app
    exit 1
fi

echo "[DASHBOARD] /app/dashboard.py found."

# ============================================================
# Start Discord bot
# ============================================================

echo "[START] Starting bot.py..."

python -u /app/bot.py &
BOT_PID=$!

sleep 2

if ! kill -0 "$BOT_PID" 2>/dev/null; then
    echo "[BOT] ERROR: bot.py exited immediately."
    wait "$BOT_PID" 2>/dev/null || true
    exit 1
fi

echo "[BOT] Running. PID: $BOT_PID"

# ============================================================
# Start dashboard
# ============================================================

echo "[START] Starting dashboard.py..."

python -u /app/dashboard.py &
DASH_PID=$!

sleep 2

if ! kill -0 "$DASH_PID" 2>/dev/null; then
    echo "[DASHBOARD] ERROR: dashboard.py exited immediately."
    wait "$DASH_PID" 2>/dev/null || true
    exit 1
fi

echo "[DASHBOARD] Running. PID: $DASH_PID"

# ============================================================
# All services started
# ============================================================

echo ""
echo "=========================================="
echo "   ALL SERVICES STARTED"
echo "=========================================="
echo "[START] BOT PID:       $BOT_PID"
echo "[START] DASHBOARD PID: $DASH_PID"
echo "[START] TMATE PID:     $TMATE_PID"
echo "=========================================="

# ============================================================
# Cleanup
# ============================================================

cleanup() {
    echo ""
    echo "=========================================="
    echo "   SHUTTING DOWN"
    echo "=========================================="

    kill "$BOT_PID" 2>/dev/null || true
    kill "$DASH_PID" 2>/dev/null || true
    kill "$TMATE_PID" 2>/dev/null || true

    wait "$BOT_PID" 2>/dev/null || true
    wait "$DASH_PID" 2>/dev/null || true
    wait "$TMATE_PID" 2>/dev/null || true

    echo "[STOP] Shutdown complete."
}

trap cleanup INT TERM EXIT

# ============================================================
# Monitor
# ============================================================

while true; do

    if ! kill -0 "$BOT_PID" 2>/dev/null; then
        echo "[ERROR] bot.py exited."

        echo "[BOT] Process output/status:"
        wait "$BOT_PID" 2>/dev/null || true

        exit 1
    fi

    if ! kill -0 "$DASH_PID" 2>/dev/null; then
        echo "[ERROR] dashboard.py exited."

        wait "$DASH_PID" 2>/dev/null || true

        exit 1
    fi

    if ! kill -0 "$TMATE_PID" 2>/dev/null; then
        echo "[ERROR] tmate-ssh-server exited."

        echo "[TMATE] Last relay log:"
        cat /tmp/tmate-relay.log 2>/dev/null || true

        exit 1
    fi

    sleep 5

done
