#!/bin/sh
set -eu

echo "=========================================="
echo "   AlwayzPlayzZ VPS DASH - STARTING"
echo "   Discord Bot + Dashboard + tmate Relay"
echo "=========================================="

# ============================================================
# tmate relay configuration
# ============================================================

TMATE_KEYS="${SSH_KEYS_PATH:-/tmate/keys}"
TMATE_PORT="${SSH_PORT_LISTEN:-2222}"
TMATE_HOST="${SSH_HOSTNAME:-}"
TMATE_ADVERTISE_PORT="${SSH_PORT_ADVERTISE:-$TMATE_PORT}"

echo "[TMATE] Key directory: $TMATE_KEYS"
echo "[TMATE] Listen port: $TMATE_PORT"
echo "[TMATE] Advertised host: ${TMATE_HOST:-NOT SET}"
echo "[TMATE] Advertised port: $TMATE_ADVERTISE_PORT"

# Make sure the persistent key directory exists.
mkdir -p "$TMATE_KEYS"

# ============================================================
# Generate tmate SSH host keys if missing
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
# Start tmate SSH relay
# ============================================================

echo "[TMATE] Starting tmate-ssh-server..."

TMATE_ARGS="
-p $TMATE_PORT
-q $TMATE_ADVERTISE_PORT
-k $TMATE_KEYS
"

if [ -n "$TMATE_HOST" ]; then
    TMATE_ARGS="$TMATE_ARGS -h $TMATE_HOST"
fi

# shellcheck disable=SC2086
tmate-ssh-server $TMATE_ARGS > /tmp/tmate-relay.log 2>&1 &
TMATE_PID=$!

echo "[TMATE] Relay PID: $TMATE_PID"

# Give relay a moment to initialize.
sleep 2

if ! kill -0 "$TMATE_PID" 2>/dev/null; then
    echo "[TMATE] ERROR: tmate-ssh-server failed to start."
    echo "[TMATE] Relay log:"
    cat /tmp/tmate-relay.log 2>/dev/null || true
    exit 1
fi

echo "[TMATE] Relay started successfully."

# ============================================================
# Start Discord bot
# ============================================================

echo "[START] Starting bot.py..."

python -u /app/bot.py &
BOT_PID=$!

sleep 2

# ============================================================
# Start dashboard
# ============================================================

echo "[START] Starting dashboard.py on 0.0.0.0:2026..."

python -u /app/dashboard.py &
DASH_PID=$!

echo "[START] Services started."
echo "[START] BOT PID: $BOT_PID"
echo "[START] DASHBOARD PID: $DASH_PID"
echo "[START] TMATE PID: $TMATE_PID"

# ============================================================
# Cleanup
# ============================================================

cleanup() {
    echo ""
    echo "[STOP] Shutting down services..."

    kill "$BOT_PID" "$DASH_PID" "$TMATE_PID" 2>/dev/null || true

    wait "$BOT_PID" "$DASH_PID" "$TMATE_PID" 2>/dev/null || true

    echo "[STOP] Shutdown complete."
}

trap cleanup INT TERM EXIT

# ============================================================
# Monitor services
# ============================================================

while true; do

    if ! kill -0 "$BOT_PID" 2>/dev/null; then
        echo "[ERROR] bot.py exited."
        exit 1
    fi

    if ! kill -0 "$DASH_PID" 2>/dev/null; then
        echo "[ERROR] dashboard.py exited."
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
