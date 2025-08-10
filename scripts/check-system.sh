#!/usr/bin/env bash
# Pre-installation check script for PI-DATV-WWATS

echo "=== PI-DATV-WWATS Pre-Installation Check ==="
echo

# Check if running on Raspberry Pi
if [ ! -f /proc/device-tree/model ] || ! grep -q "Raspberry Pi" /proc/device-tree/model 2>/dev/null; then
    echo "❌ WARNING: This doesn't appear to be a Raspberry Pi"
    echo "   This software is designed specifically for Raspberry Pi 4/5"
else
    PI_MODEL=$(cat /proc/device-tree/model 2>/dev/null)
    echo "✓ Detected: $PI_MODEL"
fi

# Check OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "✓ OS: $PRETTY_NAME"
    if [[ "$ID" == "raspbian" ]] || [[ "$NAME" == *"Raspberry Pi OS"* ]]; then
        echo "✓ Raspberry Pi OS detected"
    else
        echo "❌ WARNING: Not Raspberry Pi OS. May have compatibility issues."
    fi
else
    echo "❌ Could not detect OS version"
fi

# Check architecture
ARCH=$(uname -m)
if [[ "$ARCH" == "aarch64" ]] || [[ "$ARCH" == "armv7l" ]]; then
    echo "✓ Architecture: $ARCH (compatible)"
else
    echo "❌ WARNING: Architecture $ARCH may not be compatible"
fi

# Check for required commands
echo
echo "Checking system dependencies..."

commands=("git" "systemctl" "ffmpeg")
for cmd in "${commands[@]}"; do
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "✓ $cmd: available"
    else
        echo "❌ $cmd: missing (will be installed)"
    fi
done

# Check for USB cameras
echo
echo "Checking for USB video devices..."
if [ -d /dev ]; then
    VIDEO_DEVICES=$(ls /dev/video* 2>/dev/null || true)
    if [ -n "$VIDEO_DEVICES" ]; then
        echo "✓ Video devices found:"
        for dev in $VIDEO_DEVICES; do
            echo "  - $dev"
        done
    else
        echo "❌ No video devices found. Connect a USB camera and try again."
    fi
fi

# Check audio devices
echo
echo "Checking audio devices..."
if command -v arecord >/dev/null 2>&1; then
    AUDIO_CARDS=$(arecord -l 2>/dev/null | grep "^card" | wc -l)
    if [ "$AUDIO_CARDS" -gt 0 ]; then
        echo "✓ Audio recording devices found: $AUDIO_CARDS"
    else
        echo "❌ No audio recording devices found"
    fi
else
    echo "⚠ arecord not available (will be installed)"
fi

# Check network connectivity
echo
echo "Checking network connectivity..."
if ping -c 1 streaming.wwats.net >/dev/null 2>&1; then
    echo "✓ WWATS streaming server reachable"
else
    echo "❌ WARNING: Cannot reach streaming.wwats.net"
    echo "  Check internet connection or firewall settings"
fi

# Check GPIO access
echo
echo "Checking GPIO access..."
if [ -d /sys/class/gpio ]; then
    echo "✓ GPIO interface available"
else
    echo "❌ GPIO interface not found"
fi

# Check disk space
echo
echo "Checking disk space..."
AVAILABLE_MB=$(df / | tail -1 | awk '{print int($4/1024)}')
if [ "$AVAILABLE_MB" -gt 500 ]; then
    echo "✓ Disk space: ${AVAILABLE_MB}MB available"
else
    echo "❌ WARNING: Low disk space: ${AVAILABLE_MB}MB available"
    echo "  At least 500MB recommended"
fi

# Summary
echo
echo "=== Summary ==="
echo "If you see any ❌ errors above, please address them before installation."
echo "To proceed with installation, run: sudo ./scripts/install.sh"
echo
