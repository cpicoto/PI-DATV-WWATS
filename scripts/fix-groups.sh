#!/usr/bin/env bash
# Check user groups and fix permissions

echo "=== User Group Diagnostic ==="

echo "1. Current user groups for datv:"
groups datv

echo
echo "2. Required groups for service:"
echo "video audio plugdev render input gpio"

echo
echo "3. Checking group existence:"
for group in video audio plugdev render input gpio; do
    if getent group $group >/dev/null 2>&1; then
        echo "✓ Group '$group' exists"
    else
        echo "✗ Group '$group' does not exist"
    fi
done

echo
echo "4. Adding datv user to required groups:"
for group in video audio plugdev render input gpio; do
    if getent group $group >/dev/null 2>&1; then
        echo "Adding datv to group $group..."
        sudo usermod -a -G $group datv
    else
        echo "Skipping non-existent group: $group"
    fi
done

echo
echo "5. Updated groups for datv:"
groups datv

echo
echo "6. Restarting service..."
sudo systemctl restart rtmp-streamer.service
sleep 2
sudo systemctl status rtmp-streamer.service

echo "=== Group Fix Complete ==="
