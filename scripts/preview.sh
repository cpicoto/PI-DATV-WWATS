#!/usr/bin/env bash
# Simple split-screen preview: raw camera on left, WWATS website on right
set -euo pipefail
source /etc/rtmp-streamer.env
: "${VIDEO_DEV:=/dev/video0}"
: "${REMOTE_URL:=https://streaming.wwats.net/}"
: "${SCREEN_W:=1920}"; : "${SCREEN_H:=1080}"

echo "=== Simple Split-Screen Preview ==="

# Set up display environment
export DISPLAY=${DISPLAY:-:0}
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/tmp/runtime-$(id -u)}
mkdir -p "$XDG_RUNTIME_DIR"

# Try to get X11 authorization from the main user session
if [[ -f /home/datv/.Xauthority ]]; then
    export XAUTHORITY=/home/datv/.Xauthority
elif [[ -f /home/pi/.Xauthority ]]; then
    export XAUTHORITY=/home/pi/.Xauthority
fi

# Add current user to X11 access if possible
if command -v xhost >/dev/null 2>&1; then
    xhost +local: 2>/dev/null || true
fi

# Check if camera is available
if [[ -c "$VIDEO_DEV" ]]; then
    echo "✓ Camera found at $VIDEO_DEV"
    LOCAL_INPUT="$VIDEO_DEV"
else
    echo "⚠ No camera found at $VIDEO_DEV - using test pattern"
    LOCAL_INPUT="testsrc"
fi

# Calculate window sizes for side-by-side display
HALF_WIDTH=$((SCREEN_W / 2))

echo "Opening WWATS interface in browser (right side)..."
# Open browser with WWATS interface positioned on right side
if command -v chromium-browser >/dev/null 2>&1; then
    DISPLAY=:0 chromium-browser --no-sandbox --disable-gpu --new-window --window-position=${HALF_WIDTH},0 --window-size=${HALF_WIDTH},${SCREEN_H} "$REMOTE_URL" &
elif command -v firefox >/dev/null 2>&1; then
    DISPLAY=:0 firefox --new-window "$REMOTE_URL" &
else
    echo "No browser found - install chromium-browser or firefox"
    exit 1
fi

echo "Starting camera preview (left side)..."
# Start raw camera preview on left side with multiple fallback methods
if [[ "$LOCAL_INPUT" == "testsrc" ]]; then
    # Try different video output methods
    SDL_VIDEODRIVER=x11 ffplay -f lavfi -i "testsrc=duration=3600:size=${HALF_WIDTH}x${SCREEN_H}:rate=30" \
           -x ${HALF_WIDTH} -y ${SCREEN_H} -left 0 -top 0 2>/dev/null || \
    SDL_VIDEODRIVER=fbdev ffplay -f lavfi -i "testsrc=duration=3600:size=${HALF_WIDTH}x${SCREEN_H}:rate=30" \
           -x ${HALF_WIDTH} -y ${SCREEN_H} -left 0 -top 0 2>/dev/null || \
    ffplay -f lavfi -i "testsrc=duration=3600:size=${HALF_WIDTH}x${SCREEN_H}:rate=30" \
           -x ${HALF_WIDTH} -y ${SCREEN_H} -left 0 -top 0
else
    # Try different video output methods for camera
    SDL_VIDEODRIVER=x11 ffplay -f v4l2 -i "$LOCAL_INPUT" -x ${HALF_WIDTH} -y ${SCREEN_H} -left 0 -top 0 2>/dev/null || \
    SDL_VIDEODRIVER=fbdev ffplay -f v4l2 -i "$LOCAL_INPUT" -x ${HALF_WIDTH} -y ${SCREEN_H} -left 0 -top 0 2>/dev/null || \
    ffplay -f v4l2 -i "$LOCAL_INPUT" -x ${HALF_WIDTH} -y ${SCREEN_H} -left 0 -top 0
fi
