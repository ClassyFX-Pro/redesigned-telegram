#!/bin/sh
set -eu

echo "=========================================="
echo "   AlwayzPlayzZ VPS DASH - STARTING"
echo "   Discord Bot + Dashboard + tmate Relay"
echo "=========================================="

TMATE_KEYS="${SSH_KEYS_PATH:-/tmate/keys}"
TMATE_PORT="${SSH_PORT_LISTEN:-2222}"
TMATE_PUBLIC_HOST="${TMATE_SERVER_HOST:-}"
TMATE_PUBLIC_PORT="${TMATE_SERVER_PORT:-}"

mkdir -p "$TMATE_KEYS"
chmod 700 "$TMATE_KEYS"

echo "[TMATE] Key directory: $TMATE_KEYS"
echo "[TMATE] Listen port: $TMATE_PORT"

# ============================================================
# HOST KEYS
# ============================================================

if [ ! -f "$TMATE_KEYS/ssh_host_rsa_key" ]; then
    echo "[TMATE] Generating RSA host key..."
    ssh-keygen -t rsa -b 4096 \
        -f "$TMATE_KEYS/ssh_host_rsa_key" \
        -N ""
fi

if [ ! -f "$TMATE_KEYS/ssh_host_ed25519_key" ]; then
    echo "[TMATE] Generating ED25519 host key..."
    ssh-keygen -t ed25519 \
        -f "$TMATE_KEYS/ssh_host_ed25519_key" \
        -N ""
fi

chmod 600 "$TMATE_KEYS"/ssh_host_*_key 2>/dev/null || true

echo "[TMATE] Host keys ready."

# ============================================================
# TMATE SERVER
# ============================================================

if [ ! -x /usr/bin/tmate-ssh-server ]; then
    echo "[TMATE] ERROR: /usr/bin/tmate-ssh-server not found."
    exit 1
fi

echo "[TMATE] tmate-ssh-server found."

TMATE_PID=""

# Check whether our requested port is already occupied.
PORT_IN_USE=0

if command -v ss >/dev/null 2>&1; then
    if ss -lnt 2>/dev/null | grep -q ":${TMATE_PORT} "; then
        PORT_IN_USE=1
    fi
elif command -v netstat >/dev/null 2>&1; then
    if netstat -lnt 2>/dev/null | grep -q ":${TMATE_PORT} "; then
        PORT_IN_USE=1
    fi
fi

if [ "$PORT_IN_USE" = "1" ]; then
    echo "[TMATE] Port $TMATE_PORT is already in use."

    # Determine whether it is actually tmate-ssh-server.
    EXISTING_PID="$(pgrep -f "/usr/bin/tmate-ssh-server.*-p $TMATE_PORT" 2>/dev/null | head -n 1 || true)"

    if [ -n "$EXISTING_PID" ]; then
        echo "[TMATE] Existing tmate-ssh-server found."
        echo "[TMATE] Existing PID: $EXISTING_PID"

        TMATE_PID="$EXISTING_PID"
    else
        echo "[TMATE] ERROR: Port $TMATE_PORT is occupied by another process."
        echo "[TMATE] Cannot safely start tmate relay."
        exit 1
    fi
else
    echo "[TMATE] Starting tmate-ssh-server on port $TMATE_PORT..."

    rm -f /tmp/tmate-relay.log

    TMATE_ARGS="
        -p $TMATE_PORT
        -k $TMATE_KEYS
    "

    # Add advertised public endpoint if configured.
    if [ -n "$TMATE_PUBLIC_HOST" ] && [ -n "$TMATE_PUBLIC_PORT" ]; then
        echo "[TMATE] Public host: $TMATE_PUBLIC_HOST"
        echo "[TMATE] Public port: $TMATE_PUBLIC_PORT"

        /usr/bin/tmate-ssh-server \
            -p "$TMATE_PORT" \
            -q "$TMATE_PUBLIC_PORT" \
            -h "$TMATE_PUBLIC_HOST" \
            -k "$TMATE_KEYS" \
            > /tmp/tmate-relay.log 2>&1 &
    else
        /usr/bin/tmate-ssh-server \
            -p "$TMATE_PORT" \
            -k "$TMATE_KEYS" \
            > /tmp/tmate-relay.log 2>&1 &
    fi

    TMATE_PID=$!

    sleep 2

    if ! kill -0 "$TMATE_PID" 2>/dev/null; then
        echo ""
        echo "=========================================="
        echo "   TMATE FAILED TO START"
        echo "=========================================="

        cat /tmp/tmate-relay.log 2>/dev/null || true

        exit 1
    fi

    echo "[TMATE] Started successfully."
    echo "[TMATE] PID: $TMATE_PID"
fi

# ============================================================
# VERIFY TMATE
# ============================================================

if [ -n "$TMATE_PID" ]; then
    if ! kill -0 "$TMATE_PID" 2>/dev/null; then
        echo "[TMATE] ERROR: tmate process is not running."
        exit 1
    fi
fi

if command -v ss >/dev/null 2>&1; then
    echo "[TMATE] Listening sockets:"
    ss -lntp 2>/dev/null | grep ":$TMATE_PORT " || true
fi

echo "[TMATE] Relay is ready."

# ============================================================
# START DISCORD BOT
# ============================================================

echo ""
echo "=========================================="
echo "[START] Starting Discord bot..."
echo "=========================================="

if [ ! -f /app/vps_bot_nolxc_nodocker.py ]; then
    echo "[ERROR] Bot file does not exist:"
    echo "/app/vps_bot_nolxc_nodocker.py"
    exit 1
fi

python -u /app/vps_bot_nolxc_nodocker.py &
BOT_PID=$!

echo "[START] BOT PID: $BOT_PID"

sleep 2

if ! kill -0 "$BOT_PID" 2>/dev/null; then
    echo "[ERROR] Discord bot exited immediately."
    exit 1
fi

# ============================================================
# START DASHBOARD
# ============================================================

echo ""
echo "=========================================="
echo "[START] Starting dashboard..."
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
# ALL SERVICES STARTED
# ============================================================

echo ""
echo "=========================================="
echo "   ALL SERVICES STARTED"
echo "=========================================="
echo "[START] BOT PID:       $BOT_PID"
echo "[START] DASHBOARD PID: $DASH_PID"
echo "[START] TMATE PID:     $TMATE_PID"
echo "[START] TMATE PORT:    $TMATE_PORT"

if [ -n "$TMATE_PUBLIC_HOST" ]; then
    echo "[START] TMATE HOST:    $TMATE_PUBLIC_HOST"
fi

if [ -n "$TMATE_PUBLIC_PORT" ]; then
    echo "[START] TMATE PUB PORT: $TMATE_PUBLIC_PORT"
fi

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

    if [ -n "${BOT_PID:-}" ]; then
        if kill -0 "$BOT_PID" 2>/dev/null; then
            echo "[STOP] Stopping bot..."
            kill "$BOT_PID" 2>/dev/null || true
        fi
    fi

    if [ -n "${DASH_PID:-}" ]; then
        if kill -0 "$DASH_PID" 2>/dev/null; then
            echo "[STOP] Stopping dashboard..."
            kill "$DASH_PID" 2>/dev/null || true
        fi
    fi

    # Only stop tmate if THIS start.sh started it.
    if [ -n "${TMATE_PID:-}" ] && [ "${TMATE_STARTED:-0}" = "1" ]; then
        if kill -0 "$TMATE_PID" 2>/dev/null; then
            echo "[STOP] Stopping tmate relay..."
            kill "$TMATE_PID" 2>/dev/null || true
        fi
    fi

    wait "$BOT_PID" 2>/dev/null || true
    wait "$DASH_PID" 2>/dev/null || true

    echo "[STOP] Shutdown complete."
}

trap cleanup INT TERM EXIT

# ============================================================
# MONITOR
# ============================================================

while true; do

    if ! kill -0 "$BOT_PID" 2>/dev/null; then
        echo "[ERROR] Discord bot exited."
        exit 1
    fi

    if ! kill -0 "$DASH_PID" 2>/dev/null; then
        echo "[ERROR] Dashboard exited."
        exit 1
    fi

    if [ -n "$TMATE_PID" ]; then
        if ! kill -0 "$TMATE_PID" 2>/dev/null; then
            echo "[ERROR] tmate-ssh-server exited."

            if [ -f /tmp/tmate-relay.log ]; then
                echo ""
                echo "========== TMATE LOG =========="
                cat /tmp/tmate-relay.log || true
                echo "==============================="
            fi

            exit 1
        fi
    fi

    sleep 5

done
