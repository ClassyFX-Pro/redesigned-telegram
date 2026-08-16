#!/bin/sh
set -eu

echo "=========================================="
echo "   AlwayzPlayzZ VPS DASH - STARTING"
echo "   Discord Bot + Dashboard + tmate Relay"
echo "=========================================="

# ============================================================
# TMATE RELAY CONFIG
# ============================================================

TMATE_KEYS="${SSH_KEYS_PATH:-/tmate/keys}"
TMATE_PORT="${SSH_PORT_LISTEN:-2222}"
TMATE_HOST="${SSH_HOSTNAME:-}"
TMATE_ADVERTISE_PORT="${SSH_PORT_ADVERTISE:-$TMATE_PORT}"

echo "[TMATE] Key directory: $TMATE_KEYS"
echo "[TMATE] Listen port: $TMATE_PORT"
echo "[TMATE] Advertised host: ${TMATE_HOST:-NOT SET}"
echo "[TMATE] Advertised port: $TMATE_ADVERTISE_PORT"

mkdir -p "$TMATE_KEYS"

# ============================================================
# GENERATE SSH HOST KEYS
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
# START TMATE SSH RELAY
# ============================================================

echo "[TMATE] Starting tmate-ssh-server..."

rm -f /tmp/tmate-relay.log

# Start relay.
# The relay listens internally on 2222.
tmate-ssh-server \
    -p "$TMATE_PORT" \
    -q "$TMATE_ADVERTISE_PORT" \
    -k "$TMATE_KEYS" \
    > /tmp/tmate-relay.log 2>&1 &

TMATE_PID=$!

echo "[TMATE] Relay PID: $TMATE_PID"

sleep 3

# ============================================================
# VERIFY RELAY PROCESS
# ============================================================

if ! kill -0 "$TMATE_PID" 2>/dev/null; then
    echo ""
    echo "[TMATE] =========================================="
    echo "[TMATE] ERROR: Relay failed to start"
    echo "[TMATE] =========================================="
    echo ""

    cat /tmp/tmate-relay.log 2>/dev/null || true

    exit 1
fi

echo "[TMATE] Relay process is running."

# ============================================================
# VERIFY PORT
# ============================================================

echo "[TMATE] Checking local port $TMATE_PORT..."

if command -v ss >/dev/null 2>&1; then
    if ss -lnt 2>/dev/null | grep -q ":$TMATE_PORT "; then
        echo "[TMATE] SUCCESS: Relay is listening on port $TMATE_PORT"
    else
        echo "[TMATE] WARNING: Relay process exists but port $TMATE_PORT is not detected."
        echo "[TMATE] Relay log:"
        cat /tmp/tmate-relay.log 2>/dev/null || true
    fi
fi

echo "[TMATE] =========================================="
echo "[TMATE] Relay configuration:"
echo "[TMATE] Internal: 0.0.0.0:$TMATE_PORT"
echo "[TMATE] External: ${TMATE_HOST:-NOT SET}:$TMATE_ADVERTISE_PORT"
echo "[TMATE] =========================================="

# ============================================================
# START DISCORD BOT
# ============================================================

echo "[START] Starting bot.py..."

python -u /app/bot.py &
BOT_PID=$!

sleep 2

# ============================================================
# START DASHBOARD
# ============================================================

echo "[START] Starting dashboard.py on 0.0.0.0:2026..."

python -u /app/dashboard.py &
DASH_PID=$!

echo ""
echo "=========================================="
echo "   ALL SERVICES STARTED"
echo "=========================================="
echo "[START] BOT PID:       $BOT_PID"
echo "[START] DASHBOARD PID: $DASH_PID"
echo "[START] TMATE PID:     $TMATE_PID"
echo "[START] TMATE PORT:    $TMATE_PORT"
echo "[START] DASHBOARD:     2026"
echo "=========================================="

# ============================================================
# CLEANUP
# ============================================================

cleanup() {
    echo ""
    echo "[STOP] Shutting down services..."

    kill "$BOT_PID" "$DASH_PID" "$TMATE_PID" 2>/dev/null || true

    wait "$BOT_PID" 2>/dev/null || true
    wait "$DASH_PID" 2>/dev/null || true
    wait "$TMATE_PID" 2>/dev/null || true

    echo "[STOP] Shutdown complete."
}

trap cleanup INT TERM EXIT

# ============================================================
# MONITOR EVERYTHING
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

        echo ""
        echo "[TMATE] Last relay log:"
        cat /tmp/tmate-relay.log 2>/dev/null || true

        exit 1
    fi

    sleep 5

done
