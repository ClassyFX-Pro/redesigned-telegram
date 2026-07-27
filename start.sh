#!/bin/sh
set -eu

echo "=========================================="
echo "   AlwayzPlayzZ VPS DASH - STARTING"
echo "=========================================="

echo "[START] Starting bot.py..."
python -u /app/bot.py &
BOT_PID=$!

echo "[START] Starting dashboard.py on 0.0.0.0:2026..."
python -u /app/dashboard.py &
DASH_PID=$!

cleanup() {
    echo "[STOP] Shutting down services..."

    if kill -0 "$BOT_PID" 2>/dev/null; then
        kill "$BOT_PID" 2>/dev/null || true
    fi

    if kill -0 "$DASH_PID" 2>/dev/null; then
        kill "$DASH_PID" 2>/dev/null || true
    fi

    wait "$BOT_PID" 2>/dev/null || true
    wait "$DASH_PID" 2>/dev/null || true
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
