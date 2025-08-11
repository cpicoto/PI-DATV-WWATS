#!/usr/bin/env bash
set -euo pipefail

echo "=== PI-DATV-WWATS Uninstall Script ==="
echo "This will completely remove all PI-DATV-WWATS components from your system."
echo

# Confirm before proceeding
read -p "Are you sure you want to uninstall everything? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Uninstall cancelled."
    exit 0
fi

echo "Starting uninstall process..."

# Stop and disable all services
echo "Step 1/6: Stopping and disabling services..."
systemctl stop rtmp-streamer.service rtmp-preview.service rtmp-ui.service 2>/dev/null || true
systemctl disable rtmp-streamer.service rtmp-preview.service rtmp-ui.service 2>/dev/null || true
echo "✓ Services stopped and disabled"

# Remove systemd service files
echo "Step 2/6: Removing systemd service files..."
rm -f /etc/systemd/system/rtmp-streamer.service
rm -f /etc/systemd/system/rtmp-preview.service
rm -f /etc/systemd/system/rtmp-ui.service
systemctl daemon-reload
echo "✓ Service files removed"

# Remove application directory
echo "Step 3/6: Removing application files..."
rm -rf /opt/pi-datv-wwats
echo "✓ Application directory removed"

# Remove configuration files
echo "Step 4/6: Removing configuration files..."
rm -f /etc/rtmp-streamer.env
rm -f /etc/udev/rules.d/99-rtmp-cam.rules
rm -f /run/rtmp-status.txt
echo "✓ Configuration files removed"

# Remove autostart files
echo "Step 5/6: Removing autostart files..."
REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || echo pi)}"
USER_HOME=$(eval echo "~$REAL_USER")
rm -f "$USER_HOME/.config/autostart/rtmp-ui.desktop" 2>/dev/null || true
echo "✓ Autostart files removed"

# Reload udev rules
echo "Step 6/6: Reloading udev rules..."
udevadm control --reload-rules 2>/dev/null || true
udevadm trigger 2>/dev/null || true
echo "✓ udev rules reloaded"

echo
echo "=== Uninstall Complete! ==="
echo
echo "All PI-DATV-WWATS components have been removed from your system."
echo "Your system is now clean and ready for a fresh installation."
echo
echo "To reinstall, run:"
echo "   sudo ./scripts/install.sh"
echo
