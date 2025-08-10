#!/bin/bash
# PI-DATV-WWATS First Time Setup Script
# Run this after flashing the pre-configured image

set -e

echo "========================================="
echo "   PI-DATV-WWATS First Time Setup"
echo "========================================="
echo

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "❌ Please run this script as a regular user (not sudo)"
    echo "   Example: ./scripts/first-time-setup.sh"
    exit 1
fi

# Function to prompt for input with validation
prompt_input() {
    local prompt="$1"
    local var_name="$2"
    local example="$3"
    local value=""
    
    while [ -z "$value" ]; do
        echo -n "$prompt"
        if [ -n "$example" ]; then
            echo -n " (example: $example)"
        fi
        echo -n ": "
        read value
        if [ -z "$value" ]; then
            echo "❌ This field cannot be empty. Please try again."
        fi
    done
    
    eval "$var_name='$value'"
}

echo "🎯 This script will configure your PI-DATV-WWATS station."
echo "   You'll need your amateur radio callsign and WWATS JWT token."
echo

# Get user configuration
prompt_input "Enter your amateur radio callsign" CALLSIGN "AD7NP"
prompt_input "Enter your WWATS JWT token" TOKEN "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

echo
echo "📋 Configuration Summary:"
echo "   Callsign: $CALLSIGN"
echo "   Token: ${TOKEN:0:20}..."
echo

read -p "Is this correct? (y/N): " confirm
if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo "❌ Setup cancelled. Please run the script again."
    exit 1
fi

echo
echo "⚙️  Updating configuration..."

# Update the configuration file
sudo sed -i "s/RTMP_CALLSIGN=CHANGEME/RTMP_CALLSIGN=$CALLSIGN/" /etc/rtmp-streamer.env
sudo sed -i "s/RTMP_TOKEN=CHANGEME_YOUR_JWT_TOKEN_HERE/RTMP_TOKEN=$TOKEN/" /etc/rtmp-streamer.env

echo "✅ Configuration updated!"
echo

# Check system status
echo "🔍 Checking system status..."
if systemctl is-enabled rtmp-streamer >/dev/null 2>&1; then
    echo "✅ Services are enabled"
else
    echo "⚙️  Enabling services..."
    sudo systemctl enable rtmp-streamer rtmp-preview rtmp-ui
fi

echo
echo "🌐 WiFi Configuration:"
echo "   If you need WiFi, configure it using one of these methods:"
echo "   1. Desktop: Click WiFi icon in top-right corner"
echo "   2. Command: sudo raspi-config → Network Options → WiFi"
echo "   3. Manual: sudo nano /etc/wpa_supplicant/wpa_supplicant.conf"
echo

echo "🔧 Hardware Check:"
echo "   Make sure you have connected:"
echo "   • USB camera to any USB port"
echo "   • Button: GPIO17 (pin 11) to GND (pin 9)"
echo "   • Optional LED: GPIO27 (pin 13) → 330Ω resistor → LED → GND"
echo "   • HDMI monitor for preview display"
echo

echo "🚀 Ready to start!"
echo "   To start the streaming station:"
echo "   1. Reboot: sudo reboot"
echo "   2. After reboot, use the button or web UI to start streaming"
echo "   3. Web UI available at: http://localhost:8080"
echo

read -p "Would you like to reboot now? (y/N): " reboot_confirm
if [[ $reboot_confirm =~ ^[Yy]$ ]]; then
    echo "🔄 Rebooting..."
    sudo reboot
else
    echo "✅ Setup complete! Remember to reboot when ready."
fi
