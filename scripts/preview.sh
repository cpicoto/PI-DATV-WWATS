#!/usr/bin/env bash
set -euo pipefail
source /etc/rtmp-streamer.env
: "${PREVIEW_UDP_URL:=udp://127.0.0.1:23000}"
: "${REMOTE_URL:=https://stream.wwats.net/}"
: "${SCREEN_W:=1920}"; : "${SCREEN_H:=1080}"
: "${OVERLAY_FONT:=/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf}"

# Build lavfi graph: two movie sources -> scale -> hstack -> pad -> drawtext overlay
FILTER="movie=${PREVIEW_UDP_URL},setpts=PTS-STARTPTS,scale=${SCREEN_W}/2:${SCREEN_H}:force_original_aspect_ratio=decrease,setsar=1[loc]; \
        movie=${REMOTE_URL},setpts=PTS-STARTPTS,scale=${SCREEN_W}/2:${SCREEN_H}:force_original_aspect_ratio=decrease,setsar=1[rem]; \
        [loc][rem]hstack=inputs=2, pad=${SCREEN_W}:${SCREEN_H}:(ow-iw)/2:(oh-ih)/2:color=black, \
        drawtext=fontfile=${OVERLAY_FONT}:textfile=/run/rtmp-status.txt:reload=1:x=20:y=H-th-20:box=1:boxborderw=10:boxcolor=black@0.5"

exec ffplay -loglevel error -fflags nobuffer -flags low_delay -fast -probesize 32 -analyzeduration 0 -autoexit 0 -fs -f lavfi -i "$FILTER"
