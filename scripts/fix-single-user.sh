#!/usr/bin/env bash
# Fix ownership for single-user (datv) architecture

echo "=== Fixing Ownership for Single-User Architecture ==="

# Detect the real user (even when run with sudo)
if [[ -n "${SUDO_USER:-}" ]]; then
    REAL_USER="$SUDO_USER"
else
    REAL_USER=$(whoami)
fi

echo "Setting ownership for user: $REAL_USER"

# Fix ownership of installed files
echo "1. Fixing /opt/pi-datv-wwats/ ownership..."
sudo chown -R $REAL_USER:$REAL_USER /opt/pi-datv-wwats/

# Update services to use the correct user
echo "2. Installing updated service files..."
sudo cp services/*.service /etc/systemd/system/
sudo systemctl daemon-reload

# Add user to required groups
echo "3. Adding $REAL_USER to required groups..."
sudo usermod -a -G video,audio,plugdev,render,input,gpio $REAL_USER

# Restart services
echo "4. Restarting services..."
sudo systemctl restart rtmp-streamer.service
sudo systemctl restart rtmp-ui.service  
sudo systemctl restart rtmp-preview.service

echo "5. Checking service status..."
sudo systemctl status rtmp-streamer.service --no-pager -l
sudo systemctl status rtmp-ui.service --no-pager -l

echo "=== Single-User Setup Complete ==="
echo "All services now run as user: $REAL_USER"
echo "No more permission conflicts!"
