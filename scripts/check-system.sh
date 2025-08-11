#!/bin/bash
# Pre-installation system check for PI-DATV-WWATS

set -e

echo "=== PI-DATV-WWATS Pre-Installation Check ==="
echo

# Fix the null byte warning by filtering the output
detect_pi_model() {
    if [ -f /proc/device-tree/model ]; then
        # Filter out null bytes that cause the warning
        tr -d '\0' < /proc/device-tree/model
    else
        echo "Unknown"
    fi
}

# Detect Raspberry Pi model
PI_MODEL=$(detect_pi_model)
if [[ "$PI_MODEL" == *"Raspberry Pi"* ]]; then
    echo "✓ Detected: $PI_MODEL"
else
    echo "❌ ERROR: This doesn't appear to be a Raspberry Pi"
    echo "  Detected: $PI_MODEL"
    echo "  This project is designed specifically for Raspberry Pi hardware"
    exit 1
fi# Check OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "✓ OS: $PRETTY_NAME"
    
    # More flexible OS check - accept Raspberry Pi OS derivatives
    if [[ "$ID" == "raspbian" ]] || [[ "$NAME" == *"Raspberry Pi OS"* ]] || [[ "$PRETTY_NAME" == *"Raspberry Pi OS"* ]]; then
        echo "✓ Running Raspberry Pi OS (recommended)"
    elif [[ "$ID" == "debian" ]] && [[ "$VERSION_CODENAME" == "bookworm" ]]; then
        echo "⚠ WARNING: Debian detected instead of Raspberry Pi OS"
        echo "  This may work but Raspberry Pi OS is recommended for best compatibility"
    else
        echo "❌ WARNING: Unsupported OS detected"
        echo "  Raspberry Pi OS Bookworm is recommended"
        echo "  Continuing anyway, but you may encounter issues..."
    fi
else
    echo "❌ ERROR: Cannot detect OS version"
    exit 1
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

# Check for required commands
check_command() {
    if command -v "$1" >/dev/null 2>&1; then
        echo "✓ $1: available"
        return 0
    else
        echo "❌ $1: missing"
        return 1
    fi
}

MISSING_DEPS=0

check_command "git" || MISSING_DEPS=1
check_command "systemctl" || MISSING_DEPS=1

# Check if ffmpeg is available
if command -v ffmpeg >/dev/null 2>&1; then
    echo "✓ ffmpeg: available"
    
    # Check for hardware encoder support on Pi 4/5
    if [[ "$PI_MODEL" == *"Raspberry Pi 4"* ]] || [[ "$PI_MODEL" == *"Raspberry Pi 5"* ]]; then
        if ffmpeg -hide_banner -encoders 2>/dev/null | grep -q "h264_v4l2m2m"; then
            echo "✓ Hardware H.264 encoder: available"
        else
            echo "⚠ WARNING: Hardware H.264 encoder not detected"
            echo "  Software encoding will be used (higher CPU usage)"
        fi
    fi
else
    echo "❌ ffmpeg: missing (will be installed)"
fi

# Check for USB cameras
echo
echo "Checking for USB video devices..."

# Check for video devices
VIDEO_DEVICES=$(find /dev -name "video*" -type c 2>/dev/null | sort -V)
if [ -n "$VIDEO_DEVICES" ]; then
    echo "✓ Video devices found:"
    for dev in $VIDEO_DEVICES; do
        # Only show actual capture devices (usually video0, video2, etc.)
        if v4l2-ctl --device="$dev" --list-formats >/dev/null 2>&1; then
            DEVICE_NAME=$(v4l2-ctl --device="$dev" --info 2>/dev/null | grep "Card type" | cut -d: -f2 | xargs || echo "Unknown")
            echo "  - $dev ($DEVICE_NAME)"
        fi
    done
else
    echo "❌ WARNING: No video devices found"
    echo "  Please connect a UVC-compatible USB camera"
fi

# Check audio devices
echo
echo "Checking audio devices..."

# Check for audio recording devices
AUDIO_DEVICES=$(arecord -l 2>/dev/null | grep "^card" | wc -l)
if [ "$AUDIO_DEVICES" -gt 0 ]; then
    echo "✓ Audio recording devices found: $AUDIO_DEVICES"
    # Show available devices
    echo "  Available audio devices:"
    arecord -l 2>/dev/null | grep "^card" | while read line; do
        echo "    $line"
    done
else
    echo "❌ WARNING: No audio recording devices found"
    echo "  Check if your camera has a built-in microphone or connect a USB microphone"
fi

# Check network connectivity
echo
echo "Checking network connectivity..."

# Test basic internet connectivity first
if ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1; then
    echo "✓ Internet connectivity: available"
    
    # Test if we can resolve the streaming server
    if nslookup streaming.wwats.net >/dev/null 2>&1; then
        echo "✓ WWATS streaming server: DNS resolves"
        
        # Try to test RTMP port if nc is available
        if command -v nc >/dev/null 2>&1; then
            if timeout 3 nc -z streaming.wwats.net 1935 2>/dev/null; then
                echo "✓ WWATS RTMP port: reachable"
            else
                echo "⚠ WWATS RTMP port: may be filtered (normal for security)"
                echo "  This doesn't prevent streaming - RTMP servers often block port scanning"
            fi
        else
            echo "⚠ Cannot test RTMP port (netcat not available)"
            echo "  This is normal and doesn't affect streaming functionality"
        fi
    else
        echo "❌ WARNING: Cannot resolve streaming.wwats.net"
        echo "  Check DNS settings or internet connection"
    fi
else
    echo "❌ WARNING: No internet connectivity detected"
    echo "  Check network connection - internet required for streaming"
fi

# Check GPIO access
echo
echo "Checking GPIO access..."

# Check GPIO access
if [ -d /sys/class/gpio ]; then
    echo "✓ GPIO interface available"
    
    # Check if user is in gpio group (after installation)
    if groups | grep -q gpio; then
        echo "✓ Current user has GPIO access"
    else
        echo "⚠ Current user not in 'gpio' group (will be added during installation)"
    fi
else
    echo "❌ ERROR: GPIO interface not available"
    echo "  This is required for button control"
fi

# Check disk space
echo
echo "Checking disk space..."

# Check available disk space
AVAILABLE_KB=$(df / | awk 'NR==2 {print $4}')
AVAILABLE_MB=$((AVAILABLE_KB / 1024))

if [ "$AVAILABLE_MB" -gt 1000 ]; then
    echo "✓ Disk space: ${AVAILABLE_MB}MB available"
else
    echo "❌ WARNING: Low disk space: ${AVAILABLE_MB}MB available"
    echo "  At least 1GB free space recommended"
fi

echo
echo "Checking system memory..."

# Check RAM
TOTAL_RAM=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024)}')
if [ "$TOTAL_RAM" -gt 2048 ]; then
    echo "✓ System memory: ${TOTAL_RAM}MB (good for streaming)"
elif [ "$TOTAL_RAM" -gt 1024 ]; then
    echo "⚠ System memory: ${TOTAL_RAM}MB (adequate, may limit concurrent features)"
else
    echo "❌ WARNING: Low system memory: ${TOTAL_RAM}MB"
    echo "  4GB+ recommended for reliable streaming"
fi

# Summary
echo
echo "=== Summary ==="

if [ $MISSING_DEPS -eq 0 ]; then
    echo "✓ All critical dependencies are available"
    echo "✓ System appears ready for PI-DATV-WWATS installation"
    echo
    echo "To proceed with installation, run: sudo ./scripts/install.sh"
    echo
    echo "After installation, you'll need to configure:"
    echo "  1. Your amateur radio callsign"
    echo "  2. Your WWATS JWT token"
    echo "  3. WiFi credentials (if using WiFi)"
    echo
    echo "See README.md for complete setup instructions."
else
    echo "❌ Some dependencies are missing but will be installed during setup"
    echo "⚠ Please review any warnings above before proceeding"
    echo
    echo "To proceed anyway, run: sudo ./scripts/install.sh"
fi

exit 0
