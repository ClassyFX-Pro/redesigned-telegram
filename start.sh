#!/bin/sh
set -eu

echo "=========================================="
echo "   AlwayzPlayzZ VPS DASH - STARTING"
echo "=========================================="

echo "[START] Starting bot.py..."
exec python -u /app/bot.py
