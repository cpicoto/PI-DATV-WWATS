#!/usr/bin/env bash
# Quick update script for incremental changes
# Use this instead of full install.sh for updates

set -euo pipefail

echo "=== PI-DATV-WWATS Update Script ==="
echo "This script updates files and restarts services without full reinstall"
echo

# Check if we're in the right directory
if [[ ! -f "scripts/install.sh" ]]; then
    echo "Error: Run this from the PI-DATV-WWATS directory"
    exit 1
fi

# Check if system is already installed
if [[ ! -f "/etc/rtmp-streamer.env" ]]; then
    echo "Error: System not installed yet. Run ./scripts/install.sh first"
    exit 1
fi

echo "Updating application files..."

# Copy updated Python apps
sudo cp -v app/streamer.py /opt/pi-datv-wwats/
sudo cp -v app/rtmp-ui.py /opt/pi-datv-wwats/

# Copy updated scripts  
sudo cp -v scripts/preview.sh /opt/pi-datv-wwats/
sudo cp -v scripts/preview-browser.sh /opt/pi-datv-wwats/ 2>/dev/null || echo "preview-browser.sh not found, skipping"

# Make sure scripts are executable
sudo chmod +x /opt/pi-datv-wwats/*.sh /opt/pi-datv-wwats/*.py

# Update systemd service files if they changed
# Detect real user when running with sudo
if [[ -n "${SUDO_USER:-}" ]]; then
    CURRENT_USER="$SUDO_USER"
    CURRENT_GROUP=$(id -gn "$SUDO_USER")
else
    CURRENT_USER=$(whoami)
    CURRENT_GROUP=$(id -gn)
fi

echo "Fixing services for user: $CURRENT_USER, group: $CURRENT_GROUP"

if ! diff -q services/rtmp-streamer.service /etc/systemd/system/rtmp-streamer.service >/dev/null 2>&1; then
    echo "Updating rtmp-streamer.service..."
    sudo cp services/rtmp-streamer.service /etc/systemd/system/
    # Fix user/group in the service file
    sudo sed -i "s/^User=pi$/User=$CURRENT_USER/" /etc/systemd/system/rtmp-streamer.service
    sudo sed -i "s/^Group=pi$/Group=$CURRENT_GROUP/" /etc/systemd/system/rtmp-streamer.service
    sudo sed -i "s/^Group=video$/Group=$CURRENT_GROUP/" /etc/systemd/system/rtmp-streamer.service
    sudo sed -i '/^SupplementaryGroups=/d' /etc/systemd/system/rtmp-streamer.service
    RELOAD_SYSTEMD=1
fi

if ! diff -q services/rtmp-preview.service /etc/systemd/system/rtmp-preview.service >/dev/null 2>&1; then
    echo "Updating rtmp-preview.service..."
    sudo cp services/rtmp-preview.service /etc/systemd/system/
    # Fix user/group in the service file
    sudo sed -i "s/^User=pi$/User=$CURRENT_USER/" /etc/systemd/system/rtmp-preview.service
    sudo sed -i "s/^Group=pi$/Group=$CURRENT_GROUP/" /etc/systemd/system/rtmp-preview.service
    sudo sed -i "s/^Group=video$/Group=$CURRENT_GROUP/" /etc/systemd/system/rtmp-preview.service
    sudo sed -i '/^SupplementaryGroups=/d' /etc/systemd/system/rtmp-preview.service
    RELOAD_SYSTEMD=1
fi

if ! diff -q services/rtmp-ui.service /etc/systemd/system/rtmp-ui.service >/dev/null 2>&1; then
    echo "Updating rtmp-ui.service..."
    sudo cp services/rtmp-ui.service /etc/systemd/system/
    # Fix user/group in the service file
    sudo sed -i "s/^User=pi$/User=$CURRENT_USER/" /etc/systemd/system/rtmp-ui.service
    sudo sed -i "s/^Group=pi$/Group=$CURRENT_GROUP/" /etc/systemd/system/rtmp-ui.service
    sudo sed -i "s/^Group=video$/Group=$CURRENT_GROUP/" /etc/systemd/system/rtmp-ui.service
    sudo sed -i '/^SupplementaryGroups=/d' /etc/systemd/system/rtmp-ui.service
    RELOAD_SYSTEMD=1
fi

# Reload systemd if services changed
if [[ "${RELOAD_SYSTEMD:-}" == "1" ]]; then
    echo "Reloading systemd daemon..."
    sudo systemctl daemon-reload
fi

echo
echo "=== Restarting Services ==="

# Restart services to pick up changes
echo "Restarting rtmp-preview service..."
sudo systemctl restart rtmp-preview

echo "Restarting rtmp-ui service..."  
sudo systemctl restart rtmp-ui

# Only restart streamer if it's running (don't auto-start)
if systemctl is-active --quiet rtmp-streamer; then
    echo "Restarting rtmp-streamer service..."
    sudo systemctl restart rtmp-streamer
else
    echo "rtmp-streamer not running, skipping restart"
fi

echo
echo "=== Update Complete ==="
echo "Services status:"
systemctl status rtmp-preview --no-pager -l
systemctl status rtmp-ui --no-pager -l
echo
echo "Use 'sudo journalctl -u rtmp-preview -f' to watch preview logs"
echo "Use the web UI at http://$(hostname -I | awk '{print $1}'):8080 to control streaming"
