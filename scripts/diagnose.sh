#!/usr/bin/env bash
# Diagnostic script to debug streaming issues

echo "=== PI-DATV-WWATS Diagnostic ==="
echo "Timestamp: $(date)"
echo

echo "1. Service Status:"
systemctl is-active rtmp-streamer.service || echo "Service is not active"
systemctl is-enabled rtmp-streamer.service || echo "Service is not enabled"
echo

echo "2. Configuration File:"
if [ -f "/etc/rtmp-streamer.env" ]; then
    echo "✓ Configuration file exists"
    echo "Size: $(wc -l < /etc/rtmp-streamer.env) lines"
    # Show key settings (without sensitive tokens)
    grep -E "^(VIDEO_|AUDIO_|RTMP_BASE|RTMP_CALLSIGN|ENABLE_TEE)" /etc/rtmp-streamer.env 2>/dev/null || echo "No config vars found"
else
    echo "✗ Configuration file missing at /etc/rtmp-streamer.env"
fi
echo

echo "3. Command File Status:"
if [ -f "/tmp/rtmp-command.txt" ]; then
    echo "✓ Command file exists: $(cat /tmp/rtmp-command.txt)"
else
    echo "✗ No command file at /tmp/rtmp-command.txt"
fi
echo

echo "4. Status File:"
if [ -f "/run/rtmp-status.txt" ]; then
    echo "✓ Status file exists:"
    cat /run/rtmp-status.txt
else
    echo "✗ No status file at /run/rtmp-status.txt"
fi
echo

echo "5. Camera Status:"
if [ -c "/dev/video0" ]; then
    echo "✓ Camera device exists at /dev/video0"
    v4l2-ctl --device=/dev/video0 --list-formats-ext 2>/dev/null | head -10 || echo "Cannot query camera formats"
else
    echo "✗ No camera device at /dev/video0"
fi
echo

echo "6. UDP Stream Test:"
timeout 3 ffprobe -v quiet udp://127.0.0.1:23000 2>/dev/null && echo "✓ UDP stream available" || echo "✗ No UDP stream at 127.0.0.1:23000"
echo

echo "7. Process Status:"
pgrep -fl ffmpeg || echo "No ffmpeg processes running"
echo

echo "8. Service Logs (last 10 lines):"
journalctl -u rtmp-streamer.service --no-pager -n 10 2>/dev/null || echo "Cannot access service logs"
echo

echo "9. Web UI Process:"
pgrep -fl "python.*rtmp-ui" || echo "No rtmp-ui processes running"
echo

echo "=== Diagnostic Complete ==="
