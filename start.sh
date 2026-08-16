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

mkdir -p "$TMATE_KEYS"

# ============================================================
# Generate host keys
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
# Verify relay binary
# ============================================================

if ! command -v tmate-ssh-server >/dev/null 2>&1; then
    echo "[TMATE] FATAL: tmate-ssh-server was not found!"
    exit 1
fi

echo "[TMATE] Binary: $(command -v tmate-ssh-server)"

# ============================================================
# Start tmate SSH relay
# ============================================================

echo "[TMATE] Starting tmate-ssh-server..."

# Build arguments as positional parameters instead of a string.
set -- \
    -p "$TMATE_PORT" \
    -q "$TMATE_ADVERTISE_PORT" \
    -k "$TMATE_KEYS"

if [ -n "$TMATE_HOST" ]; then
    set -- "$@" -h "$TMATE_HOST"
fi

echo "[TMATE] Command:"
printf '[TMATE]   tmate-ssh-server'
for arg in "$@"; do
    printf ' %s' "$arg"
done
printf '\n'

tmate-ssh-server "$@" > /tmp/tmate-relay.log 2>&1 &
TMATE_PID=$!

echo "[TMATE] Relay PID: $TMATE_PID"

sleep 3

# ============================================================
# Verify relay process
# ============================================================

if ! kill -0 "$TMATE_PID" 2>/dev/null; then
    echo "[TMATE] FATAL: tmate-ssh-server exited during startup."
    echo "========== TMATE RELAY LOG =========="
    cat /tmp/tmate-relay.log 2>/dev/null || true
    echo "======================================"
    exit 1
fi

echo "[TMATE] Relay process is running."

# Check that the relay actually opened the port.
if command -v ss >/dev/null 2>&1; then
    echo "[TMATE] Listening sockets:"
    ss -lntp 2>/dev/null | grep ":$TMATE_PORT" || {
        echo "[TMATE] WARNING: Nothing appears to be listening on :$TMATE_PORT"
        echo "========== TMATE RELAY LOG =========="
        cat /tmp/tmate-relay.log 2>/dev/null || true
        echo "======================================"
    }
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

        echo "========== TMATE RELAY LOG =========="
        cat /tmp/tmate-relay.log 2>/dev/null || true
        echo "======================================"

        exit 1
    fi

    sleep 5

done
