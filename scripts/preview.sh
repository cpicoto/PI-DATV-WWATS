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
echo "Debug: Checking with ss command..."
ss -uln 2>/dev/null | grep ":23000 " && echo "ss found port 23000" || echo "ss did not find port 23000"
echo "Debug: Checking with netstat command..."
netstat -uln 2>/dev/null | grep ":23000 " && echo "netstat found port 23000" || echo "netstat did not find port 23000"

if ss -uln 2>/dev/null | grep -q ":23000 " || netstat -uln 2>/dev/null | grep -q ":23000 "; then
    echo "✓ Local UDP stream detected"
    LOCAL_INPUT="${PREVIEW_UDP_URL}"
else
    echo "⚠ No local UDP stream found - using test pattern"
    LOCAL_INPUT="testsrc"
fi

# Check remote stream accessibility 
echo "Checking remote stream..."
# Try direct URL first (main stream interface)
if timeout 5s ffprobe -v quiet "${REMOTE_URL}" 2>/dev/null; then
    echo "✓ Remote stream accessible (direct URL)"
    REMOTE_INPUT="${REMOTE_URL}"
else
    # Try HLS format as fallback
    HLS_URL="${REMOTE_URL%/}/index.m3u8"  # Remove trailing slash to avoid double slash
    if timeout 5s ffprobe -v quiet "$HLS_URL" 2>/dev/null; then
        echo "✓ Remote HLS stream accessible"
        REMOTE_INPUT="$HLS_URL"
    else
        echo "⚠ Remote stream not accessible (tried both direct and HLS) - using test pattern"
        REMOTE_INPUT="testsrc"
    fi
fi

echo "Local input: $LOCAL_INPUT"
echo "Remote input: $REMOTE_INPUT"

# Build filter - handle different input types
if [[ "$LOCAL_INPUT" == "testsrc" ]] && [[ "$REMOTE_INPUT" == "testsrc" ]]; then
    # Both test sources - use lavfi with proper syntax
    echo "Using test pattern mode"
    exec ffplay -f lavfi -i "testsrc=duration=3600:size=${SCREEN_W}x${SCREEN_H}:rate=30,drawtext=text='Preview - No Streams Available':fontfile=${OVERLAY_FONT}:x=50:y=50:fontsize=32:fontcolor=white" -fs
    
elif [[ "$LOCAL_INPUT" != "testsrc" ]] && [[ "$REMOTE_INPUT" != "testsrc" ]]; then
    # Both real streams - use multiple inputs
    FILTER="[0:v]scale=${SCREEN_W}/2:${SCREEN_H}[loc]; \
[1:v]scale=${SCREEN_W}/2:${SCREEN_H}[rem]; \
[loc][rem]hstack=inputs=2[combined]; \
[combined]drawtext=fontfile=${OVERLAY_FONT}:textfile=/run/rtmp-status.txt:reload=1:x=20:y=H-th-20:fontsize=24:fontcolor=white:box=1:boxcolor=black@0.5[out]"
    
    echo "Using dual stream mode"
    echo "Command: ffplay -i \"$LOCAL_INPUT\" -i \"$REMOTE_INPUT\" -filter_complex \"$FILTER\" -map \"[out]\" -fs"
    exec ffplay -i "$LOCAL_INPUT" -i "$REMOTE_INPUT" -filter_complex "$FILTER" -map "[out]" -fs
    
else
    # Mixed mode - fallback to single stream or web interface
    if [[ "$LOCAL_INPUT" != "testsrc" ]]; then
        echo "Using local stream only (remote appears to be web interface, not video stream)"
        echo "Command: ffplay \"$LOCAL_INPUT\" -fs"
        exec ffplay "$LOCAL_INPUT" -fs
    else
        echo "No video streams available - the remote URL appears to be a web interface"
        echo "Consider opening $REMOTE_URL in a browser for monitoring"
        # Show test pattern with instruction
        exec ffplay -f lavfi -i "testsrc=duration=3600:size=${SCREEN_W}x${SCREEN_H}:rate=30,drawtext=text='No video streams available - Open ${REMOTE_URL} in browser for monitoring':fontfile=${OVERLAY_FONT}:x=50:y=50:fontsize=24:fontcolor=white" -fs
    fi
fi
