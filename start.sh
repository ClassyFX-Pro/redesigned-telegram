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
TMATE_PUBLIC_HOST="${TMATE_SERVER_HOST:-}"
TMATE_PUBLIC_PORT="${TMATE_SERVER_PORT:-}"

TMATE_PID=""
TMATE_STARTED=0
BOT_PID=""
DASH_PID=""

echo "[TMATE] Key directory: $TMATE_KEYS"
echo "[TMATE] Listen port: $TMATE_PORT"

if [ -n "$TMATE_PUBLIC_HOST" ]; then
    echo "[TMATE] Public host: $TMATE_PUBLIC_HOST"
fi

if [ -n "$TMATE_PUBLIC_PORT" ]; then
    echo "[TMATE] Public port: $TMATE_PUBLIC_PORT"
fi

# ============================================================
# CREATE KEY DIRECTORY
# ============================================================

mkdir -p "$TMATE_KEYS"
chmod 700 "$TMATE_KEYS"

# ============================================================
# GENERATE HOST KEYS
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
# CHECK TMATE SERVER
# ============================================================

if [ ! -x /usr/bin/tmate-ssh-server ]; then
    echo "[TMATE] ERROR: /usr/bin/tmate-ssh-server not found."
    exit 1
fi

echo "[TMATE] tmate-ssh-server found:"
ls -lh /usr/bin/tmate-ssh-server

# ============================================================
# FUNCTION: CHECK PORT
# ============================================================

port_is_listening() {
    if command -v ss >/dev/null 2>&1; then
        ss -lnt 2>/dev/null | grep -q ":${TMATE_PORT} "
        return $?
    fi

    if command -v netstat >/dev/null 2>&1; then
        netstat -lnt 2>/dev/null | grep -q ":${TMATE_PORT} "
        return $?
    fi

    return 1
}

# ============================================================
# FIND EXISTING TMATE SERVER
# ============================================================

EXISTING_PID=""

if command -v pgrep >/dev/null 2>&1; then
    EXISTING_PID="$(
        pgrep -f "/usr/bin/tmate-ssh-server" 2>/dev/null |
        while read -r pid; do
            [ "$pid" = "$$" ] && continue

            args="$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null || true)"

            case "$args" in
                *"-p $TMATE_PORT"*)
                    echo "$pid"
                    break
                    ;;
            esac
        done
    )"
fi

# ============================================================
# REMOVE OLD / INCORRECT TMATE SERVER
# ============================================================

if [ -n "$EXISTING_PID" ]; then

    EXISTING_ARGS="$(tr '\0' ' ' < "/proc/$EXISTING_PID/cmdline" 2>/dev/null || true)"

    echo "[TMATE] Existing server found:"
    echo "[TMATE] PID:  $EXISTING_PID"
    echo "[TMATE] CMD:  $EXISTING_ARGS"

    # We specifically need the public hostname and port.
    # An old server such as:
    #
    # /usr/bin/tmate-ssh-server -p 2222 -k /tmate/keys
    #
    # does NOT contain the Railway advertised endpoint.
    #
    # Therefore terminate it and replace it with the correctly
    # configured instance.

    NEED_RESTART=0

    case "$EXISTING_ARGS" in
        *"-h $TMATE_PUBLIC_HOST"*)
            ;;
        *)
            if [ -n "$TMATE_PUBLIC_HOST" ]; then
                NEED_RESTART=1
            fi
            ;;
    esac

    case "$EXISTING_ARGS" in
        *"-q $TMATE_PUBLIC_PORT"*)
            ;;
        *)
            if [ -n "$TMATE_PUBLIC_PORT" ]; then
                NEED_RESTART=1
            fi
            ;;
    esac

    if [ "$NEED_RESTART" = "1" ]; then

        echo "[TMATE] Existing relay does not have the required"
        echo "[TMATE] Railway public endpoint configuration."
        echo "[TMATE] Stopping old relay..."

        kill "$EXISTING_PID" 2>/dev/null || true

        # Give it a moment to exit.
        i=0
        while kill -0 "$EXISTING_PID" 2>/dev/null; do
            i=$((i + 1))

            if [ "$i" -ge 10 ]; then
                echo "[TMATE] Old relay did not stop normally."
                echo "[TMATE] Sending SIGKILL to PID $EXISTING_PID."
                kill -9 "$EXISTING_PID" 2>/dev/null || true
                break
            fi

            sleep 1
        done

        EXISTING_PID=""
        echo "[TMATE] Old relay removed."

    else

        echo "[TMATE] Existing relay already has the correct configuration."
        TMATE_PID="$EXISTING_PID"
        TMATE_STARTED=0

    fi
fi

# ============================================================
# START CORRECT TMATE SERVER
# ============================================================

if [ -z "$TMATE_PID" ]; then

    if port_is_listening; then
        echo "[TMATE] ERROR: Port $TMATE_PORT is still occupied."
        echo "[TMATE] Current listeners:"

        if command -v ss >/dev/null 2>&1; then
            ss -lntp 2>/dev/null | grep ":${TMATE_PORT} " || true
        fi

        exit 1
    fi

    rm -f /tmp/tmate-relay.log

    echo ""
    echo "=========================================="
    echo "   STARTING TMATE SSH RELAY"
    echo "=========================================="
    echo "[TMATE] Listen: 0.0.0.0:$TMATE_PORT"

    if [ -n "$TMATE_PUBLIC_HOST" ]; then
        echo "[TMATE] Advertised host: $TMATE_PUBLIC_HOST"
    fi

    if [ -n "$TMATE_PUBLIC_PORT" ]; then
        echo "[TMATE] Advertised port: $TMATE_PUBLIC_PORT"
    fi

    # --------------------------------------------------------
    # Build command
    # --------------------------------------------------------

    if [ -n "$TMATE_PUBLIC_HOST" ] && [ -n "$TMATE_PUBLIC_PORT" ]; then

        echo "[TMATE] Starting with Railway public endpoint..."

        /usr/bin/tmate-ssh-server \
            -p "$TMATE_PORT" \
            -q "$TMATE_PUBLIC_PORT" \
            -h "$TMATE_PUBLIC_HOST" \
            -k "$TMATE_KEYS" \
            > /tmp/tmate-relay.log 2>&1 &

    else

        echo "[TMATE] Starting without custom public endpoint..."

        /usr/bin/tmate-ssh-server \
            -p "$TMATE_PORT" \
            -k "$TMATE_KEYS" \
            > /tmp/tmate-relay.log 2>&1 &

    fi

    TMATE_PID=$!
    TMATE_STARTED=1

    echo "[TMATE] New relay PID: $TMATE_PID"

    sleep 2

    # --------------------------------------------------------
    # Verify process
    # --------------------------------------------------------

    if ! kill -0 "$TMATE_PID" 2>/dev/null; then

        echo ""
        echo "=========================================="
        echo "   TMATE FAILED TO START"
        echo "=========================================="

        cat /tmp/tmate-relay.log 2>/dev/null || true

        exit 1
    fi

    echo "[TMATE] Process is alive."

fi

# ============================================================
# VERIFY LISTENING
# ============================================================

sleep 1

echo ""
echo "=========================================="
echo "   TMATE RELAY STATUS"
echo "=========================================="

echo "[TMATE] PID: $TMATE_PID"
echo "[TMATE] Port: $TMATE_PORT"

if command -v ss >/dev/null 2>&1; then

    if ss -lntp 2>/dev/null | grep -q ":${TMATE_PORT} "; then
        echo "[TMATE] Listening successfully."
        ss -lntp 2>/dev/null | grep ":${TMATE_PORT} " || true
    else
        echo "[TMATE] WARNING: Port not visible yet."
    fi

fi

if [ -f /tmp/tmate-relay.log ]; then
    echo ""
    echo "[TMATE] Relay startup log:"
    cat /tmp/tmate-relay.log 2>/dev/null || true
fi

echo "=========================================="

# ============================================================
# START DISCORD BOT
# ============================================================

echo ""
echo "=========================================="
echo "   STARTING DISCORD BOT"
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
echo "   STARTING DASHBOARD"
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
    echo "[START] TMATE PUB:     $TMATE_PUBLIC_PORT"
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

    # --------------------------------------------------------
    # BOT
    # --------------------------------------------------------

    if [ -n "${BOT_PID:-}" ]; then

        if kill -0 "$BOT_PID" 2>/dev/null; then
            echo "[STOP] Stopping bot..."
            kill "$BOT_PID" 2>/dev/null || true
        fi

    fi

    # --------------------------------------------------------
    # DASHBOARD
    # --------------------------------------------------------

    if [ -n "${DASH_PID:-}" ]; then

        if kill -0 "$DASH_PID" 2>/dev/null; then
            echo "[STOP] Stopping dashboard..."
            kill "$DASH_PID" 2>/dev/null || true
        fi

    fi

    # --------------------------------------------------------
    # TMATE
    # --------------------------------------------------------

    # Only stop the relay if THIS start.sh launched it.
    if [ "${TMATE_STARTED:-0}" = "1" ]; then

        if [ -n "${TMATE_PID:-}" ]; then

            if kill -0 "$TMATE_PID" 2>/dev/null; then
                echo "[STOP] Stopping tmate relay..."
                kill "$TMATE_PID" 2>/dev/null || true
            fi

        fi

    else

        echo "[STOP] Leaving existing tmate relay running."

    fi

    wait "${BOT_PID:-}" 2>/dev/null || true
    wait "${DASH_PID:-}" 2>/dev/null || true
    wait "${TMATE_PID:-}" 2>/dev/null || true

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

        exit 1

    fi

    # --------------------------------------------------------
    # DASHBOARD
    # --------------------------------------------------------

    if ! kill -0 "$DASH_PID" 2>/dev/null; then

        echo "[ERROR] Dashboard exited."

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

        exit 1

    fi

    sleep 5

done
