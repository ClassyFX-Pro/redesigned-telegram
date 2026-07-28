#!/bin/sh
set -eu

echo "=========================================="
echo "   AlwayzPlayzZ VPS DASH - STARTING"
echo "=========================================="

# Start the Discord bot
echo "[START] Starting bot.py..."
python -u /app/bot.py &
BOT_PID=$!

# Give the bot a second to initialize
sleep 2

# Start the dashboard
echo "[START] Starting dashboard.py on 0.0.0.0:2026..."
python -u /app/dashboard.py &
DASH_PID=$!

cleanup() {
    echo "[STOP] Shutting down services..."
    kill "$BOT_PID" "$DASH_PID" 2>/dev/null || true
    wait "$BOT_PID" "$DASH_PID" 2>/dev/null || true
}

trap cleanup INT TERM EXIT

while true; do
    if ! kill -0 "$BOT_PID" 2>/dev/null; then
        echo "[ERROR] bot.py exited. Stopping container."
        exit 1
    fi

    if ! kill -0 "$DASH_PID" 2>/dev/null; then
        echo "[ERROR] dashboard.py exited. Stopping container."
        exit 1
    fi

    sleep 5
done
