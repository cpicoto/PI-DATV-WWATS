#!/usr/bin/env bash
# Quick fix script to update user/group in systemd services
set -euo pipefail

echo "=== Fixing systemd service user/group configuration ==="

CURRENT_USER=$(whoami)
CURRENT_GROUP=$(id -gn)

echo "Updating services for user: $CURRENT_USER, group: $CURRENT_GROUP"

# Fix all three services
for service in rtmp-preview rtmp-streamer rtmp-ui; do
    echo "Fixing $service.service..."
    sudo sed -i "s/^User=pi$/User=$CURRENT_USER/" /etc/systemd/system/$service.service
    sudo sed -i "s/^Group=video$/Group=$CURRENT_GROUP/" /etc/systemd/system/$service.service
    sudo sed -i '/^SupplementaryGroups=/d' /etc/systemd/system/$service.service
done

echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

echo "Restarting preview service..."
sudo systemctl restart rtmp-preview

echo "Service status:"
systemctl status rtmp-preview --no-pager -l

echo
echo "=== Fix complete! ==="
echo "Check logs with: sudo journalctl -u rtmp-preview -f"
