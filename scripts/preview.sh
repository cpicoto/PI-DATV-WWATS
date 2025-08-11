#!/usr/bin/env bash
set -euo pipefail
source /etc/rtmp-streamer.env
: "${PREVIEW_UDP_URL:=udp://127.0.0.1:23000}"
: "${REMOTE_URL:=https://stream.wwats.net/}"
: "${SCREEN_W:=1920}"; : "${SCREEN_H:=1080}"
: "${OVERLAY_FONT:=/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf}"

echo "=== DEBUG: Preview Script Starting ==="

# Set up display environment
export DISPLAY=${DISPLAY:-:0}
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/tmp/runtime-$(id -u)}
mkdir -p "$XDG_RUNTIME_DIR"

echo "Display environment: DISPLAY=$DISPLAY, XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR"

# Check if local UDP stream is available
echo "Checking for local UDP stream..."
if ss -ulpn 2>/dev/null | grep -q ":23000 " || netstat -uln 2>/dev/null | grep -q ":23000 "; then
    echo "✓ Local UDP stream detected"
    LOCAL_INPUT="${PREVIEW_UDP_URL}"
else
    echo "⚠ No local UDP stream found - using test pattern"
    LOCAL_INPUT="testsrc"
fi

# Check remote stream accessibility 
echo "Checking remote stream..."
if timeout 5s ffprobe -v quiet "${REMOTE_URL}/index.m3u8" 2>/dev/null; then
    echo "✓ Remote HLS stream accessible"
    REMOTE_INPUT="${REMOTE_URL}/index.m3u8"
elif timeout 5s ffprobe -v quiet "${REMOTE_URL}" 2>/dev/null; then
    echo "✓ Remote stream accessible"
    REMOTE_INPUT="${REMOTE_URL}"
else
    echo "⚠ Remote stream not accessible - using test pattern"
    REMOTE_INPUT="testsrc"
fi

echo "Local input: $LOCAL_INPUT"
echo "Remote input: $REMOTE_INPUT"

# Build filter - handle different input types
if [[ "$LOCAL_INPUT" == "testsrc" ]] && [[ "$REMOTE_INPUT" == "testsrc" ]]; then
    # Both test sources - use lavfi with proper syntax
    echo "Using test pattern mode"
    exec ffplay -f lavfi -i "testsrc=duration=3600:size=${SCREEN_W}:${SCREEN_H}:rate=30,drawtext=text='Preview - No Streams Available':fontfile=${OVERLAY_FONT}:x=50:y=50:fontsize=32:fontcolor=white" -fs -autoexit 0
    
elif [[ "$LOCAL_INPUT" != "testsrc" ]] && [[ "$REMOTE_INPUT" != "testsrc" ]]; then
    # Both real streams - use multiple inputs
    FILTER="[0:v]scale=${SCREEN_W}/2:${SCREEN_H}[loc]; \
[1:v]scale=${SCREEN_W}/2:${SCREEN_H}[rem]; \
[loc][rem]hstack=inputs=2[combined]; \
[combined]drawtext=fontfile=${OVERLAY_FONT}:textfile=/run/rtmp-status.txt:reload=1:x=20:y=H-th-20:fontsize=24:fontcolor=white:box=1:boxcolor=black@0.5[out]"
    
    echo "Using dual stream mode"
    echo "Command: ffplay -i \"$LOCAL_INPUT\" -i \"$REMOTE_INPUT\" -filter_complex \"$FILTER\" -map \"[out]\" -fs -autoexit 0"
    exec ffplay -i "$LOCAL_INPUT" -i "$REMOTE_INPUT" -filter_complex "$FILTER" -map "[out]" -fs -autoexit 0
    
else
    # Mixed mode - fallback to single stream
    if [[ "$LOCAL_INPUT" != "testsrc" ]]; then
        echo "Using local stream only"
        exec ffplay -i "$LOCAL_INPUT" -fs -autoexit 0
    else
        echo "Using remote stream only"
        exec ffplay -i "$REMOTE_INPUT" -fs -autoexit 0
    fi
fi
