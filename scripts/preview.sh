#!/usr/bin/env bash
# Clean layout: WWATS (right) + Camera + Web UI (left column)
set -euo pipefail
source /etc/rtmp-streamer.env
: "${VIDEO_DEV:=/dev/video0}"
: "${REMOTE_URL:=https://streaming.wwats.net/}"
: "${SCREEN_W:=1920}"; : "${SCREEN_H:=1080}"

echo "=== Clean Layout Preview (WWATS + Camera + Web UI) ==="

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
    echo "⚠ Camera not found at $VIDEO_DEV, using test pattern"
    LOCAL_INPUT="testsrc"
fi

echo "Configuration:"
echo "- REMOTE_URL: $REMOTE_URL"
echo "- LOCAL_INPUT: $LOCAL_INPUT"
echo "- Screen: ${SCREEN_W}x${SCREEN_H}"

# Clean up any existing browser processes to avoid conflicts
echo "Cleaning up existing browser processes..."
pkill -f "chromium" 2>/dev/null || true
pkill -f "firefox" 2>/dev/null || true
# Clean up old user data directories to prevent conflicts
rm -rf "$HOME/.chrome-wwats" "$HOME/.chrome-webui" 2>/dev/null || true
sleep 2

# Calculate layout dimensions
# Left column: 480px wide (1/4 of 1920)
# Right area: Remaining space for WWATS with proper aspect ratio
LEFT_COL_WIDTH=480
WWATS_X=${LEFT_COL_WIDTH}
WWATS_WIDTH=$((SCREEN_W - LEFT_COL_WIDTH))
WWATS_HEIGHT=${SCREEN_H}

# Camera window (top of left column)
CAMERA_X=0
CAMERA_Y=0
CAMERA_WIDTH=${LEFT_COL_WIDTH}
CAMERA_HEIGHT=360  # 16:9 aspect ratio

# Web UI window (bottom of left column)
WEBUI_X=0
WEBUI_Y=$((CAMERA_HEIGHT + 10))  # 10px gap
WEBUI_WIDTH=${LEFT_COL_WIDTH}
WEBUI_HEIGHT=$((SCREEN_H - CAMERA_HEIGHT - 10))  # Remaining space

echo "Opening WWATS interface (right side)..."
# Open WWATS in windowed mode on the right side
if command -v chromium >/dev/null 2>&1; then
    DISPLAY=:0 chromium --no-sandbox --disable-gpu --disable-dev-shm-usage --user-data-dir="$HOME/.chrome-wwats" --new-window --window-position=${WWATS_X},0 --window-size=${WWATS_WIDTH},${WWATS_HEIGHT} "$REMOTE_URL" &
elif command -v chromium-browser >/dev/null 2>&1; then
    DISPLAY=:0 chromium-browser --no-sandbox --disable-gpu --disable-dev-shm-usage --user-data-dir="$HOME/.chrome-wwats" --new-window --window-position=${WWATS_X},0 --window-size=${WWATS_WIDTH},${WWATS_HEIGHT} "$REMOTE_URL" &
elif command -v firefox >/dev/null 2>&1; then
    DISPLAY=:0 firefox --new-instance --new-window "$REMOTE_URL" &
else
    echo "No browser found - install chromium or firefox"
    exit 1
fi

# Wait a moment for browser to start
sleep 3

echo "Opening local web UI (bottom left)..."
# Open local web UI in bottom left area
if command -v chromium >/dev/null 2>&1; then
    DISPLAY=:0 chromium --no-sandbox --disable-gpu --disable-dev-shm-usage --user-data-dir="$HOME/.chrome-webui" --new-window --window-position=${WEBUI_X},${WEBUI_Y} --window-size=${WEBUI_WIDTH},${WEBUI_HEIGHT} "http://localhost:8080" &
elif command -v chromium-browser >/dev/null 2>&1; then
    DISPLAY=:0 chromium-browser --no-sandbox --disable-gpu --disable-dev-shm-usage --user-data-dir="$HOME/.chrome-webui" --new-window --window-position=${WEBUI_X},${WEBUI_Y} --window-size=${WEBUI_WIDTH},${WEBUI_HEIGHT} "http://localhost:8080" &
elif command -v firefox >/dev/null 2>&1; then
    DISPLAY=:0 firefox --new-instance --new-window "http://localhost:8080" &
fi

# Wait for web UI to load
sleep 2

echo "Opening camera preview (top left)..."
# Camera preview positioned in top left area
if [[ "$LOCAL_INPUT" == "testsrc" ]]; then
    # Test pattern in top left
    SDL_VIDEODRIVER=x11 ffplay -f lavfi -i "testsrc=duration=3600:size=${CAMERA_WIDTH}x${CAMERA_HEIGHT}:rate=30" \
           -x ${CAMERA_WIDTH} -y ${CAMERA_HEIGHT} -left ${CAMERA_X} -top ${CAMERA_Y} -noborder 2>/dev/null || \
    SDL_VIDEODRIVER=fbdev ffplay -f lavfi -i "testsrc=duration=3600:size=${CAMERA_WIDTH}x${CAMERA_HEIGHT}:rate=30" \
           -x ${CAMERA_WIDTH} -y ${CAMERA_HEIGHT} -left ${CAMERA_X} -top ${CAMERA_Y} -noborder 2>/dev/null || \
    ffplay -f lavfi -i "testsrc=duration=3600:size=${CAMERA_WIDTH}x${CAMERA_HEIGHT}:rate=30" \
           -x ${CAMERA_WIDTH} -y ${CAMERA_HEIGHT} -left ${CAMERA_X} -top ${CAMERA_Y} -noborder &
else
    # Camera in top left
    SDL_VIDEODRIVER=x11 ffplay -f v4l2 -i "$LOCAL_INPUT" -x ${CAMERA_WIDTH} -y ${CAMERA_HEIGHT} -left ${CAMERA_X} -top ${CAMERA_Y} -noborder 2>/dev/null || \
    SDL_VIDEODRIVER=fbdev ffplay -f v4l2 -i "$LOCAL_INPUT" -x ${CAMERA_WIDTH} -y ${CAMERA_HEIGHT} -left ${CAMERA_X} -top ${CAMERA_Y} -noborder 2>/dev/null || \
    ffplay -f v4l2 -i "$LOCAL_INPUT" -x ${CAMERA_WIDTH} -y ${CAMERA_HEIGHT} -left ${CAMERA_X} -top ${CAMERA_Y} -noborder &
fi

echo "Preview layout setup complete!"
echo "- Camera: Top left (${CAMERA_WIDTH}x${CAMERA_HEIGHT})"
echo "- Web UI: Bottom left (${WEBUI_WIDTH}x${WEBUI_HEIGHT})"  
echo "- WWATS: Right side (${WWATS_WIDTH}x${WWATS_HEIGHT})"
echo ""
echo "Press Ctrl+C to close all windows and exit"

# Wait for user to interrupt or processes to finish
wait
