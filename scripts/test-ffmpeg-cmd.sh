#!/bin/bash

# FFmpeg Command Validation Script
# Tests the FFmpeg command syntax without actually running it

echo "=== FFmpeg Command Validation ==="
echo "Testing FFmpeg command syntax from streamer.py..."
echo

# Simulate the exact command that would be generated
FFMPEG_CMD="ffmpeg -y \
  -f v4l2 \
  -thread_queue_size 4096 \
  -input_format mjpeg \
  -video_size 1280x720 \
  -framerate 15 \
  -i /dev/video0 \
  -f lavfi \
  -i anullsrc=channel_layout=stereo:sample_rate=48000 \
  -c:v libx264 \
  -preset ultrafast \
  -tune zerolatency \
  -profile:v baseline \
  -level:v 3.0 \
  -pix_fmt yuv420p \
  -g 30 \
  -keyint_min 30 \
  -sc_threshold 0 \
  -b:v 2M \
  -maxrate 2.2M \
  -bufsize 1M \
  -x264-params keyint=30:min-keyint=30:scenecut=0:rc-lookahead=0:sliced-threads=1:sync-lookahead=0:me=dia:subme=1:me_range=4:partitions=none:weightb=0:weightp=0:8x8dct=0:fast-pskip=1:mixed-refs=0:trellis=0:chroma-me=0 \
  -c:a aac \
  -b:a 128k \
  -ar 48000 \
  -ac 2 \
  -f tee \
  '[f=flv]rtmp://streaming.wwats.net/live/TEST?token=TEST|[f=mpegts]udp://127.0.0.1:23000'"

echo "Generated FFmpeg command:"
echo "$FFMPEG_CMD"
echo

# Test command syntax (dry run)
echo "Testing command syntax with -f null output..."
TEST_CMD=$(echo "$FFMPEG_CMD" | sed 's/-f tee.*$/-t 1 -f null -/')

echo "Test command:"
echo "$TEST_CMD"
echo

# Check if camera exists
if [ -c /dev/video0 ]; then
    echo "✓ Camera device /dev/video0 exists"
    echo "Running syntax test (1 second dry run)..."
    
    if timeout 10 $TEST_CMD 2>&1 | grep -q "fps="; then
        echo "✓ FFmpeg command syntax appears correct"
        echo "✓ Camera can be accessed"
    else
        echo "✗ FFmpeg command may have issues"
        echo "Running detailed test..."
        timeout 5 $TEST_CMD
    fi
else
    echo "! Camera device /dev/video0 not found on this system"
    echo "Command syntax can't be fully tested without camera"
fi

echo
echo "=== Test Complete ==="
echo "If syntax test passed, the command should work on Pi with camera"
