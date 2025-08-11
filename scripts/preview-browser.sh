#!/usr/bin/env bash
# Alternative preview script that uses browser for remote stream display
# This script opens the WWATS web interface in a browser window alongside local stream

set -euo pipefail
source /etc/rtmp-streamer.env
: "${PREVIEW_UDP_URL:=udp://127.0.0.1:23000}"
: "${REMOTE_URL:=https://streaming.wwats.net/}"
: "${SCREEN_W:=1920}"; : "${SCREEN_H:=1080}"

echo "=== Browser-based Preview Mode ==="

# Set up display environment
export DISPLAY=${DISPLAY:-:0}
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/tmp/runtime-$(id -u)}
mkdir -p "$XDG_RUNTIME_DIR"

# Check if local UDP stream is available
if ss -uln 2>/dev/null | grep -q ":23000 " || netstat -uln 2>/dev/null | grep -q ":23000 "; then
    echo "✓ Local UDP stream detected"
    LOCAL_INPUT="${PREVIEW_UDP_URL}"
else
    echo "⚠ No local UDP stream found - using test pattern"
    LOCAL_INPUT="testsrc"
fi

# Calculate window sizes for side-by-side display
HALF_WIDTH=$((SCREEN_W / 2))

echo "Opening WWATS interface in browser (right side)..."
# Open browser with WWATS interface positioned on right side
if command -v chromium-browser >/dev/null 2>&1; then
    chromium-browser --new-window --window-position=${HALF_WIDTH},0 --window-size=${HALF_WIDTH},${SCREEN_H} "$REMOTE_URL" &
elif command -v firefox >/dev/null 2>&1; then
    firefox --new-window "$REMOTE_URL" &
else
    echo "No browser found - install chromium-browser or firefox"
    exit 1
fi

echo "Starting local stream (left side)..."
# Start FFplay with local stream on left side
if [[ "$LOCAL_INPUT" == "testsrc" ]]; then
    ffplay -f lavfi -i "testsrc=duration=3600:size=${HALF_WIDTH}:${SCREEN_H}:rate=30" \
           -x ${HALF_WIDTH} -y ${SCREEN_H} -left 0 -top 0 -alwaysontop
else
    ffplay -i "$LOCAL_INPUT" -x ${HALF_WIDTH} -y ${SCREEN_H} -left 0 -top 0 -alwaysontop
fi
