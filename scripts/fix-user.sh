#!/usr/bin/env bash
# Quick fix script to update user/group in systemd services
set -euo pipefail

echo "=== Fixing systemd service user/group configuration ==="

# Detect the actual user (not root when using sudo)
if [[ -n "${SUDO_USER:-}" ]]; then
    CURRENT_USER="$SUDO_USER"
    CURRENT_GROUP=$(id -gn "$SUDO_USER")
else
    CURRENT_USER=$(whoami)
    CURRENT_GROUP=$(id -gn)
fi

echo "Updating services for user: $CURRENT_USER, group: $CURRENT_GROUP"

# Fix all three services
for service in rtmp-preview rtmp-streamer rtmp-ui; do
    echo "Fixing $service.service..."
    sudo sed -i "s/^User=.*$/User=$CURRENT_USER/" /etc/systemd/system/$service.service
    sudo sed -i "s/^Group=.*$/Group=$CURRENT_GROUP/" /etc/systemd/system/$service.service
    sudo sed -i '/^SupplementaryGroups=/d' /etc/systemd/system/$service.service
done

echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

echo "Restarting services..."
sudo systemctl restart rtmp-ui rtmp-preview

echo "Service status:"
systemctl status rtmp-ui rtmp-preview --no-pager -l

echo
echo "=== Fix complete! ==="
echo "Check logs with: sudo journalctl -u rtmp-ui -u rtmp-preview -f"
