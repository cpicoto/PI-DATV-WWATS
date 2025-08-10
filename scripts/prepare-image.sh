#!/bin/bash
# Prepare the PI-DATV-WWATS image for distribution
# Run this BEFORE creating the image file

echo "🧹 Cleaning image for distribution..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Please run with sudo: sudo ./scripts/prepare-image.sh"
    exit 1
fi

# Stop all services
echo "⏹️  Stopping services..."
systemctl stop rtmp-streamer rtmp-preview rtmp-ui 2>/dev/null || true

# Clear system logs
echo "🗑️  Clearing system logs..."
journalctl --vacuum-time=1s
rm -rf /var/log/*.log /var/log/syslog.* /var/log/kern.log.* 2>/dev/null || true

# Clear bash history
echo "🗑️  Clearing command history..."
history -c 2>/dev/null || true
history -w 2>/dev/null || true
rm -f /root/.bash_history 2>/dev/null || true
rm -f /home/pi/.bash_history 2>/dev/null || true
rm -f /home/*/.bash_history 2>/dev/null || true

# Clear temporary files
echo "🗑️  Clearing temporary files..."
rm -rf /tmp/* /var/tmp/* 2>/dev/null || true
rm -rf /var/cache/apt/archives/* 2>/dev/null || true

# Remove personal WiFi credentials (user will reconfigure)
echo "🌐 Removing WiFi credentials..."
rm -f /etc/wpa_supplicant/wpa_supplicant.conf 2>/dev/null || true

# Remove SSH host keys (will regenerate on first boot)
echo "🔑 Removing SSH host keys..."
rm -f /etc/ssh/ssh_host_* 2>/dev/null || true

# Clear any personal SSH keys
echo "🔑 Clearing personal SSH keys..."
rm -rf /home/*/.ssh/authorized_keys /home/*/.ssh/known_hosts 2>/dev/null || true
rm -rf /root/.ssh/authorized_keys /root/.ssh/known_hosts 2>/dev/null || true

# Set the template configuration
echo "⚙️  Installing template configuration..."
if [ -f /opt/pi-datv-wwats/../config/rtmp-streamer.env.template ]; then
    cp /opt/pi-datv-wwats/../config/rtmp-streamer.env.template /etc/rtmp-streamer.env
elif [ -f config/rtmp-streamer.env.template ]; then
    cp config/rtmp-streamer.env.template /etc/rtmp-streamer.env
else
    echo "⚠️  Template config not found, creating basic template..."
    cat > /etc/rtmp-streamer.env << 'EOF'
# ===== WWATS PI-DATV CONFIG TEMPLATE =====
# IMPORTANT: Configure your callsign and token after first boot!
# Run: ./scripts/first-time-setup.sh

RTMP_CALLSIGN=CHANGEME
RTMP_TOKEN=CHANGEME_YOUR_JWT_TOKEN_HERE

# Default hardware settings
RTMP_BASE=rtmp://streaming.wwats.net/live
VIDEO_DEV=/dev/video0
VIDEO_WIDTH=1920
VIDEO_HEIGHT=1080
VIDEO_FPS=30
VIDEO_INPUT_FORMAT=mjpeg
AUDIO_DEV=default
AUDIO_RATE=48000
BUTTON_GPIO=17
LED_GPIO=27
ENCODER=h264_v4l2m2m
BITRATE=4000k
GOP_SECONDS=2
PROFILE=high
VF_FILTER=
ENABLE_TEE_PREVIEW=1
PREVIEW_UDP_URL=udp://127.0.0.1:23000?pkt_size=1316
REMOTE_URL=https://stream.wwats.net/
SCREEN_W=1920
SCREEN_H=1080
OVERLAY_FONT=/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf
ENABLE_UI=1
UI_PORT=8080
RECONNECT_WAIT=2
MAX_RECONNECT=0
EOF
fi

chmod 600 /etc/rtmp-streamer.env

# Make sure services are enabled but stopped for first boot
echo "⚙️  Configuring services..."
systemctl enable rtmp-streamer rtmp-preview rtmp-ui
systemctl disable ssh 2>/dev/null || true  # User can enable if needed

# Enable SSH key regeneration on first boot
echo "🔑 Setting up SSH key regeneration..."
systemctl enable ssh-keygen 2>/dev/null || true

# Clear package cache
echo "🗑️  Clearing package cache..."
apt-get clean 2>/dev/null || true

# Disable swap to reduce wear on SD card
echo "💾 Disabling swap..."
swapoff -a 2>/dev/null || true
systemctl disable dphys-swapfile 2>/dev/null || true

# Set hostname to default for image
echo "🏷️  Setting generic hostname..."
echo "pi-datv-wwats" > /etc/hostname
sed -i 's/127.0.1.1.*/127.0.1.1\tpi-datv-wwats/' /etc/hosts

echo
echo "✅ Image cleaned and ready for distribution!"
echo
echo "📋 Next steps:"
echo "   1. sudo shutdown -h now"
echo "   2. Remove SD card and create image file"
echo "   3. Distribute image with first-time-setup instructions"
echo
echo "💡 Users will run: ./scripts/first-time-setup.sh after flashing"
