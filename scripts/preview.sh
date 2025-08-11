#!/usr/bin/env bash
set -euo pipefail
source /etc/rtmp-streamer.env
: "${PREVIEW_UDP_URL:=udp://127.0.0.1:23000}"
: "${REMOTE_URL:=https://stream.wwats.net/}"
: "${SCREEN_W:=1920}"; : "${SCREEN_H:=1080}"
: "${OVERLAY_FONT:=/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf}"

echo "=== DEBUG: Preview Script Starting ==="
echo "PREVIEW_UDP_URL: ${PREVIEW_UDP_URL}"
echo "REMOTE_URL: ${REMOTE_URL}"
echo "SCREEN_W: ${SCREEN_W}"
echo "SCREEN_H: ${SCREEN_H}"
echo "OVERLAY_FONT: ${OVERLAY_FONT}"
echo

# Build complex filter for split screen with overlay
FILTER="[0:v]setpts=PTS-STARTPTS,scale=${SCREEN_W}/2:${SCREEN_H}:force_original_aspect_ratio=decrease,setsar=1[loc]; \
[1:v]setpts=PTS-STARTPTS,scale=${SCREEN_W}/2:${SCREEN_H}:force_original_aspect_ratio=decrease,setsar=1[rem]; \
[loc][rem]hstack=inputs=2[combined]; \
[combined]pad=${SCREEN_W}:${SCREEN_H}:(ow-iw)/2:(oh-ih)/2:color=black[padded]; \
[padded]drawtext=fontfile=${OVERLAY_FONT}:textfile=/run/rtmp-status.txt:reload=1:x=20:y=H-th-20:fontsize=24:fontcolor=white:box=1:boxborderw=10:boxcolor=black@0.5[out]"

echo "=== DEBUG: Filter Complex ==="
echo "${FILTER}"
echo

# Test different approaches
echo "=== DEBUG: Testing FFmpeg version ==="
ffmpeg -version | head -1

echo
echo "=== DEBUG: Testing input accessibility ==="
echo "Checking UDP stream availability..."
timeout 3s ffprobe -v quiet -print_format json -show_streams "${PREVIEW_UDP_URL}" 2>/dev/null && echo "UDP stream accessible" || echo "UDP stream not accessible"

echo "Checking remote stream availability..."
timeout 10s ffprobe -v quiet -print_format json -show_streams "${REMOTE_URL}" 2>/dev/null && echo "Remote stream accessible" || echo "Remote stream not accessible"

echo
echo "=== DEBUG: Attempting simple ffplay test ==="
echo "Testing simple ffplay with first input only..."
timeout 5s ffplay -loglevel error -autoexit -t 2 "${PREVIEW_UDP_URL}" 2>&1 || echo "Simple UDP test failed"

echo
echo "=== DEBUG: Building ffplay command ==="
CMD="ffplay -loglevel info -fflags nobuffer -flags low_delay -fast -probesize 32 -analyzeduration 0 -autoexit 0 -fs \
    -i \"${PREVIEW_UDP_URL}\" \
    -i \"${REMOTE_URL}\" \
    -filter_complex \"${FILTER}\" \
    -map \"[out]\""

echo "Full command:"
echo "${CMD}"
echo

echo "=== DEBUG: Executing command ==="
exec ffplay -loglevel info -fflags nobuffer -flags low_delay -fast -probesize 32 -analyzeduration 0 -autoexit 0 -fs \
    -i "${PREVIEW_UDP_URL}" \
    -i "${REMOTE_URL}" \
    -filter_complex "${FILTER}" \
    -map "[out]"
