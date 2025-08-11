#!/usr/bin/env bash
set -euo pipefail

echo "=== PI-DATV-WWATS Installation Script ==="
echo "Setting up Raspberry Pi RTMP streaming station for WWATS..."
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Please run with sudo: sudo ./scripts/install.sh"
    exit 1
fi

# Detect actual user (not root)
REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo pi)}"
USER_HOME="/home/$REAL_USER"

echo "Installing for user: $REAL_USER"
echo "User home: $USER_HOME"
echo

# Check OS version
if ! grep -q "Raspberry Pi OS" /etc/os-release 2>/dev/null; then
    echo "WARNING: This script is designed for Raspberry Pi OS. Proceeding anyway..."
fi

echo "Step 1/7: Updating package lists..."
apt-get update

echo "Step 2/7: Installing base packages..."
apt-get install -y ffmpeg python3-gpiozero python3-pip v4l-utils fontconfig
apt-get install -y python3-flask

echo "Step 3/7: Installing browser for kiosk (optional)..."
apt-get install -y chromium-browser || apt-get install -y chromium || {
    echo "WARNING: Could not install Chromium browser. Kiosk UI may not work."
}

echo "Step 4/7: Creating application directory and copying files..."
mkdir -p /opt/pi-datv-wwats
cp -a app/. /opt/pi-datv-wwats/

# Set correct permissions for Python scripts
chmod +x /opt/pi-datv-wwats/streamer.py
chmod +x /opt/pi-datv-wwats/rtmp-ui.py
echo "✓ Application files installed with correct permissions"

echo "Step 5/7: Setting up configuration..."
if [ ! -f /etc/rtmp-streamer.env ]; then
    mkdir -p /etc
    cp config/rtmp-streamer.env.sample /etc/rtmp-streamer.env
    chmod 600 /etc/rtmp-streamer.env
    chown "$REAL_USER:$REAL_USER" /etc/rtmp-streamer.env
    echo "✓ Created /etc/rtmp-streamer.env"
    echo "  IMPORTANT: Edit this file to set your CALLSIGN and TOKEN!"
else
    echo "✓ Configuration file /etc/rtmp-streamer.env already exists"
    # Ensure correct ownership for existing file
    chown "$REAL_USER:$REAL_USER" /etc/rtmp-streamer.env
fi

# Optional udev rules
if [ -f config/99-rtmp-cam.rules ]; then
    echo "Installing camera udev rules..."
    cp config/99-rtmp-cam.rules /etc/udev/rules.d/
    udevadm control --reload-rules || true
    udevadm trigger || true
    echo "✓ Camera udev rules installed"
fi

# Preview script
echo "Installing preview script..."
install -m 0755 scripts/preview.sh /opt/pi-datv-wwats/preview.sh

echo "Step 6/7: Installing systemd services..."
# Install and customize service files with correct user and group
USER_GROUP=$(id -gn "$REAL_USER")
for service in rtmp-streamer rtmp-preview rtmp-ui; do
    echo "Installing ${service}.service for user $REAL_USER (group: $USER_GROUP)..."
    # Replace user and group settings, and comment out SupplementaryGroups (user already has group memberships)
    sed -e "s/User=pi/User=$REAL_USER/g" \
        -e "s/Group=pi/Group=$USER_GROUP/g" \
        -e "s/Group=video/Group=$USER_GROUP/g" \
        -e "s/^SupplementaryGroups=/#SupplementaryGroups=/" \
        "services/${service}.service" > "/etc/systemd/system/${service}.service"
    chmod 0644 "/etc/systemd/system/${service}.service"
done

# Set up user permissions
echo "Setting up user permissions for $REAL_USER..."
usermod -aG video,audio,plugdev,render,input,gpio "$REAL_USER" || {
    echo "WARNING: Could not add user to some groups. Manual setup may be needed."
}

echo "Step 7/7: Enabling and starting services..."
systemctl daemon-reload
systemctl enable rtmp-streamer.service rtmp-preview.service rtmp-ui.service
echo "✓ Services enabled for auto-start"

# Start services (but don't fail if they can't start yet due to missing config)
echo "Starting services..."
systemctl start rtmp-ui.service || echo "WARNING: rtmp-ui service failed to start"
systemctl start rtmp-preview.service || echo "WARNING: rtmp-preview service failed to start" 
systemctl start rtmp-streamer.service || echo "WARNING: rtmp-streamer service failed to start (configure /etc/rtmp-streamer.env first)"

# Kiosk autostart setup
if [ -d "$USER_HOME" ]; then
    echo "Setting up kiosk autostart for desktop sessions..."
    install -d -o "$REAL_USER" -g "$REAL_USER" "$USER_HOME/.config/autostart" 2>/dev/null || true
    if [ -f kiosk/kiosk-autostart.desktop ]; then
        install -m 0644 -o "$REAL_USER" -g "$REAL_USER" kiosk/kiosk-autostart.desktop "$USER_HOME/.config/autostart/rtmp-ui.desktop" 2>/dev/null || {
            echo "WARNING: Could not set up kiosk autostart. Desktop may not be available."
        }
    fi
fi

echo
echo "=== Installation Complete! ==="
echo
echo "NEXT STEPS:"
echo "1. Edit the configuration file:"
echo "   sudo nano /etc/rtmp-streamer.env"
echo "   - Set your RTMP_CALLSIGN (e.g., AD7NP)"  
echo "   - Set your RTMP_TOKEN (get from WWATS)"
echo
echo "2. Test your camera and audio:"
echo "   v4l2-ctl --list-devices"
echo "   arecord -l"
echo
echo "3. Reboot to start all services:"
echo "   sudo reboot"
echo
echo "4. After reboot, access the web UI at:"
echo "   http://localhost:8080"
echo "   or http://$(hostname -I | awk '{print $1}'):8080 from another device"
echo
echo "5. Use the GPIO button on pin 11 (GPIO17) to toggle streaming"
echo
echo "For troubleshooting, check service logs:"
echo "   sudo journalctl -u rtmp-streamer -f"
echo "   sudo journalctl -u rtmp-preview -f"  
echo "   sudo journalctl -u rtmp-ui -f"
