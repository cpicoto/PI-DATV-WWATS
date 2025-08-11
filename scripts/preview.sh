#!/usr/bin/env bash
# PIP preview: WWATS full-screen + local web UI + camera overlay
set -euo pipefail
source /etc/rtmp-streamer.env
: "${VIDEO_DEV:=/dev/video0}"
: "${REMOTE_URL:=https://streaming.wwats.net/}"
: "${SCREEN_W:=1920}"; : "${SCREEN_H:=1080}"

echo "=== Picture-in-Picture Preview (WWATS + Web UI + Camera) ==="

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

# Calculate PIP size (1/4 of screen = 1/2 width and 1/2 height)
PIP_WIDTH=$((SCREEN_W / 4))
PIP_HEIGHT=$((SCREEN_H / 4))
WEB_UI_X=$((SCREEN_W - PIP_WIDTH - 20))  # Web UI in top-right corner
WEB_UI_Y=20  # 20px margin from top edge
CAMERA_X=$((SCREEN_W - PIP_WIDTH - 20))  # Camera below web UI
CAMERA_Y=$((WEB_UI_Y + PIP_HEIGHT + 10)) # 10px gap between web UI and camera

echo "Opening WWATS interface full-screen (background)..."
# Open browser with WWATS interface full-screen as background
if command -v chromium-browser >/dev/null 2>&1; then
    DISPLAY=:0 chromium-browser --no-sandbox --disable-gpu --kiosk "$REMOTE_URL" &
elif command -v firefox >/dev/null 2>&1; then
    DISPLAY=:0 firefox --kiosk "$REMOTE_URL" &
else
    echo "No browser found - install chromium-browser or firefox"
    exit 1
fi

# Wait a moment for browser to start
sleep 3

echo "Opening local web UI in overlay window..."
# Open local web UI in small window (for Start/Stop buttons)
if command -v chromium-browser >/dev/null 2>&1; then
    DISPLAY=:0 chromium-browser --no-sandbox --disable-gpu --new-window --window-position=${WEB_UI_X},${WEB_UI_Y} --window-size=${PIP_WIDTH},${PIP_HEIGHT} "http://localhost:8080" &
elif command -v firefox >/dev/null 2>&1; then
    DISPLAY=:0 firefox --new-window "http://localhost:8080" &
fi

# Wait for web UI to load
sleep 2

echo "Starting camera PIP overlay (below web UI)..."
# Start camera as small overlay window below the web UI
if [[ "$LOCAL_INPUT" == "testsrc" ]]; then
    # Try different video output methods for test pattern
    SDL_VIDEODRIVER=x11 ffplay -f lavfi -i "testsrc=duration=3600:size=${PIP_WIDTH}x${PIP_HEIGHT}:rate=30" \
           -x ${PIP_WIDTH} -y ${PIP_HEIGHT} -left ${CAMERA_X} -top ${CAMERA_Y} -alwaysontop 2>/dev/null || \
    SDL_VIDEODRIVER=fbdev ffplay -f lavfi -i "testsrc=duration=3600:size=${PIP_WIDTH}x${PIP_HEIGHT}:rate=30" \
           -x ${PIP_WIDTH} -y ${PIP_HEIGHT} -left ${CAMERA_X} -top ${CAMERA_Y} -alwaysontop 2>/dev/null || \
    ffplay -f lavfi -i "testsrc=duration=3600:size=${PIP_WIDTH}x${PIP_HEIGHT}:rate=30" \
           -x ${PIP_WIDTH} -y ${PIP_HEIGHT} -left ${CAMERA_X} -top ${CAMERA_Y} -alwaysontop
else
    # Try different video output methods for camera PIP
    SDL_VIDEODRIVER=x11 ffplay -f v4l2 -i "$LOCAL_INPUT" -x ${PIP_WIDTH} -y ${PIP_HEIGHT} -left ${CAMERA_X} -top ${CAMERA_Y} -alwaysontop 2>/dev/null || \
    SDL_VIDEODRIVER=fbdev ffplay -f v4l2 -i "$LOCAL_INPUT" -x ${PIP_WIDTH} -y ${PIP_HEIGHT} -left ${CAMERA_X} -top ${CAMERA_Y} -alwaysontop 2>/dev/null || \
    ffplay -f v4l2 -i "$LOCAL_INPUT" -x ${PIP_WIDTH} -y ${PIP_HEIGHT} -left ${CAMERA_X} -top ${CAMERA_Y} -alwaysontop
fi
