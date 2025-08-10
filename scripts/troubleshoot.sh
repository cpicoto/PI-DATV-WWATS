#!/usr/bin/env bash
# Troubleshooting script for PI-DATV-WWATS

echo "=== PI-DATV-WWATS Troubleshooting ==="
echo

# Check services status
echo "1. Service Status:"
echo "=================="
for service in rtmp-streamer rtmp-preview rtmp-ui; do
    status=$(systemctl is-active $service 2>/dev/null || echo "not-found")
    enabled=$(systemctl is-enabled $service 2>/dev/null || echo "not-found")
    echo "$service: $status (enabled: $enabled)"
done
echo

# Check configuration
echo "2. Configuration:"
echo "================="
if [ -f /etc/rtmp-streamer.env ]; then
    echo "✓ Configuration file exists: /etc/rtmp-streamer.env"
    
    # Check for required settings (without showing sensitive data)
    if grep -q "RTMP_CALLSIGN=.*[A-Z]" /etc/rtmp-streamer.env; then
        echo "✓ RTMP_CALLSIGN is set"
    else
        echo "❌ RTMP_CALLSIGN not set or invalid"
    fi
    
    if grep -q "RTMP_TOKEN=.*[a-zA-Z0-9]" /etc/rtmp-streamer.env && ! grep -q "REPLACE_WITH_YOUR_JWT" /etc/rtmp-streamer.env; then
        echo "✓ RTMP_TOKEN appears to be set"
    else
        echo "❌ RTMP_TOKEN not set or still using default"
    fi
    
    # Check file permissions
    perms=$(stat -c %a /etc/rtmp-streamer.env 2>/dev/null)
    if [ "$perms" = "600" ]; then
        echo "✓ Configuration file permissions correct (600)"
    else
        echo "⚠ Configuration file permissions: $perms (should be 600)"
    fi
else
    echo "❌ Configuration file missing: /etc/rtmp-streamer.env"
fi
echo

# Check video devices
echo "3. Video Devices:"
echo "================="
if command -v v4l2-ctl >/dev/null 2>&1; then
    video_devices=$(ls /dev/video* 2>/dev/null || echo "none")
    if [ "$video_devices" != "none" ]; then
        echo "Video devices found:"
        for dev in $video_devices; do
            echo "  $dev"
            if [ -r "$dev" ]; then
                echo "    ✓ Readable"
            else
                echo "    ❌ Not readable (check permissions)"
            fi
        done
    else
        echo "❌ No video devices found"
    fi
else
    echo "⚠ v4l2-ctl not available"
fi
echo

# Check audio devices
echo "4. Audio Devices:"
echo "================="
if command -v arecord >/dev/null 2>&1; then
    echo "Audio recording devices:"
    arecord -l 2>/dev/null | grep "^card" || echo "No audio recording devices found"
else
    echo "⚠ arecord not available"
fi
echo

# Check network connectivity
echo "5. Network Connectivity:"
echo "========================"
if ping -c 1 -W 5 streaming.wwats.net >/dev/null 2>&1; then
    echo "✓ Can reach streaming.wwats.net"
else
    echo "❌ Cannot reach streaming.wwats.net (check internet connection)"
fi

if ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
    echo "✓ Internet connectivity working"
else
    echo "❌ No internet connectivity"
fi
echo

# Check GPIO
echo "6. GPIO Access:"
echo "==============="
if [ -d /sys/class/gpio ]; then
    echo "✓ GPIO interface available"
    
    # Check if user is in gpio group
    current_user=$(whoami)
    if groups "$current_user" | grep -q gpio; then
        echo "✓ User $current_user is in gpio group"
    else
        echo "❌ User $current_user not in gpio group"
    fi
else
    echo "❌ GPIO interface not available"
fi
echo

# Check recent logs
echo "7. Recent Service Logs:"
echo "======================="
echo "Last 5 lines from rtmp-streamer service:"
journalctl -u rtmp-streamer -n 5 --no-pager 2>/dev/null || echo "No logs available"
echo

# Check processes
echo "8. Running Processes:"
echo "===================="
ffmpeg_count=$(pgrep -c ffmpeg 2>/dev/null || echo 0)
echo "FFmpeg processes running: $ffmpeg_count"

python_count=$(pgrep -c -f "streamer.py" 2>/dev/null || echo 0)
echo "Streamer processes running: $python_count"
echo

# Port check
echo "9. Port Status:"
echo "==============="
if command -v netstat >/dev/null 2>&1; then
    port_8080=$(netstat -ln | grep ":8080" | wc -l)
    if [ "$port_8080" -gt 0 ]; then
        echo "✓ Port 8080 is in use (web UI should be accessible)"
    else
        echo "❌ Port 8080 not in use (web UI may not be running)"
    fi
else
    echo "⚠ netstat not available"
fi
echo

echo "=== Quick Fixes ==="
echo "If you see issues above, try these commands:"
echo
echo "• Restart all services:"
echo "  sudo systemctl restart rtmp-streamer rtmp-preview rtmp-ui"
echo
echo "• View live service logs:"
echo "  sudo journalctl -u rtmp-streamer -f"
echo
echo "• Edit configuration:"
echo "  sudo nano /etc/rtmp-streamer.env"
echo
echo "• Fix configuration permissions:"
echo "  sudo chmod 600 /etc/rtmp-streamer.env"
echo
echo "• Check camera:"
echo "  v4l2-ctl --list-devices"
echo "  v4l2-ctl --list-formats-ext"
echo
echo "• Check audio:"
echo "  arecord -l"
echo "  arecord -D default -f cd -t wav -d 5 test.wav"
echo
