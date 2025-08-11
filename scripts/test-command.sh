#!/usr/bin/env bash
# Quick test for web UI command functionality

echo "=== Testing Web UI Command Communication ==="

echo "1. Sending START command..."
echo "start" > /tmp/rtmp-command.txt
echo "✓ Command file created with 'start'"

echo "2. Waiting 5 seconds for streamer to process..."
sleep 5

echo "3. Checking if command was processed..."
if [ -f "/tmp/rtmp-command.txt" ]; then
    echo "✗ Command file still exists - not processed"
    echo "Content: $(cat /tmp/rtmp-command.txt)"
else
    echo "✓ Command file was consumed by streamer"
fi

echo "4. Checking status file..."
if [ -f "/run/rtmp-status.txt" ]; then
    echo "✓ Status file contents:"
    cat /run/rtmp-status.txt
else
    echo "✗ No status file found"
fi

echo "5. Checking for ffmpeg process..."
if pgrep ffmpeg > /dev/null; then
    echo "✓ FFmpeg process is running"
    pgrep -fl ffmpeg
else
    echo "✗ No FFmpeg process found"
fi

echo "=== Test Complete ==="
