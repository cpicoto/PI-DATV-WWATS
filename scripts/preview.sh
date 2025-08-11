#!/usr/bin/env bash
set -euo pipefail
source /etc/rtmp-streamer.env
: "${PREVIEW_UDP_URL:=udp://127.0.0.1:23000}"
: "${REMOTE_URL:=https://stream.wwats.net/}"
: "${SCREEN_W:=1920}"; : "${SCREEN_H:=1080}"
: "${OVERLAY_FONT:=/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf}"

# Build complex filter for split screen with overlay
FILTER="[0:v]setpts=PTS-STARTPTS,scale=${SCREEN_W}/2:${SCREEN_H}:force_original_aspect_ratio=decrease,setsar=1[loc]; \
[1:v]setpts=PTS-STARTPTS,scale=${SCREEN_W}/2:${SCREEN_H}:force_original_aspect_ratio=decrease,setsar=1[rem]; \
[loc][rem]hstack=inputs=2[combined]; \
[combined]pad=${SCREEN_W}:${SCREEN_H}:(ow-iw)/2:(oh-ih)/2:color=black[padded]; \
[padded]drawtext=fontfile=${OVERLAY_FONT}:textfile=/run/rtmp-status.txt:reload=1:x=20:y=H-th-20:fontsize=24:fontcolor=white:box=1:boxborderw=10:boxcolor=black@0.5[out]"

exec ffplay -loglevel error -fflags nobuffer -flags low_delay -fast -probesize 32 -analyzeduration 0 -autoexit 0 -fs \
    -i "${PREVIEW_UDP_URL}?pkt_size=1316" \
    -i "${REMOTE_URL}" \
    -filter_complex "${FILTER}" \
    -map "[out]"
