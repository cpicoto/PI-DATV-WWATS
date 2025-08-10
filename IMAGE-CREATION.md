# PI-DATV-WWATS Pre-configured Image Creation Guide

This guide explains how to create and distribute pre-configured Raspberry Pi images for the PI-DATV-WWATS project. This approach allows users to simply flash an image and configure only their personal settings (callsign, JWT token, WiFi) rather than going through the full installation process.

## 🎯 Overview

The pre-configured image approach provides:
- ✅ All software pre-installed and configured
- ✅ Services ready to run on first boot
- ✅ Simple first-time setup for users
- ✅ Consistent, tested deployment
- ✅ Reduced chance of installation errors

## 🛠️ Image Creation Process

### Step 1: Prepare Base System

Start with a fresh Raspberry Pi OS installation:

```bash
# Flash Raspberry Pi OS (64-bit Desktop) to SD card
# Use Raspberry Pi Imager: https://rpi.org/imager

# Boot the Pi and complete initial setup:
# - Enable SSH (if remote access needed)
# - Set timezone
# - Update system
sudo apt update && sudo apt upgrade -y
```

### Step 2: Install PI-DATV-WWATS

Clone and install the project:

```bash
# Clone the repository
git clone https://github.com/YOUR-USERNAME/PI-DATV-WWATS.git
cd PI-DATV-WWATS

# Run the installation script
sudo chmod +x scripts/install.sh
sudo ./scripts/install.sh
```

Follow the prompts but use temporary values for callsign and JWT token (these will be reconfigured by end users).

### Step 3: Test the Installation

Verify everything works:

```bash
# Check system status
./scripts/check-system.sh

# Test with a camera connected
sudo systemctl start rtmp-streamer
sudo systemctl status rtmp-streamer

# Stop for image preparation
sudo systemctl stop rtmp-streamer rtmp-preview rtmp-ui
```

### Step 4: Prepare Image for Distribution

Clean the system for distribution:

```bash
# Make the prepare script executable
sudo chmod +x scripts/prepare-image.sh

# Run the image preparation script
sudo ./scripts/prepare-image.sh
```

This script will:
- Stop all services
- Clear logs and temporary files
- Remove personal data (WiFi credentials, SSH keys)
- Install template configuration
- Prepare for first-boot configuration

### Step 5: Create Image File

Power down and create the image:

```bash
# Shutdown the Pi
sudo shutdown -h now
```

Remove the SD card and create an image file using your preferred method:

**Windows (Win32 Disk Imager):**
1. Install Win32 Disk Imager
2. Insert SD card
3. Select "Read" mode
4. Choose output file: `pi-datv-wwats-v1.0.img`
5. Click "Read" to create image

**Linux/macOS (dd command):**
```bash
# Find the SD card device
lsblk

# Create image (replace /dev/sdX with your SD card)
sudo dd if=/dev/sdX of=pi-datv-wwats-v1.0.img bs=4M status=progress

# Compress the image
gzip pi-datv-wwats-v1.0.img
```

## 📦 Distribution Package

Create a distribution package containing:

```
pi-datv-wwats-image-v1.0/
├── pi-datv-wwats-v1.0.img.gz          # Compressed image file
├── FLASH-INSTRUCTIONS.md              # Flashing instructions
├── FIRST-TIME-SETUP.md               # Post-flash setup guide
├── scripts/
│   └── first-time-setup.sh           # Setup script for users
└── config/
    └── sample-config.env             # Configuration examples
```

## 📝 User Instructions

### For Image Users - Quick Start

1. **Flash the Image**
   - Download the `.img.gz` file
   - Use Raspberry Pi Imager to flash to SD card (≥32GB recommended)
   - Insert SD card into Pi 4B and boot

2. **Connect Hardware**
   - UVC USB camera to any USB port
   - Optional: GPIO button between GPIO17 and GND
   - HDMI monitor for preview (optional)

3. **Initial Setup**
   - Connect to WiFi through desktop
   - Open terminal and run:
   ```bash
   cd PI-DATV-WWATS
   ./scripts/first-time-setup.sh
   ```

4. **Configure Your Settings**
   - Enter your callsign when prompted
   - Enter your WWATS JWT token
   - System will start automatically

## 🔧 Advanced Configuration

### Customizing the Base Image

Before running `prepare-image.sh`, you can customize:

**Desktop Environment:**
```bash
# Install additional software
sudo apt install -y your-favorite-software

# Configure desktop appearance
# Set wallpaper, taskbar, etc.
```

**System Optimization:**
```bash
# GPU memory split for better encoding
echo "gpu_mem=128" | sudo tee -a /boot/config.txt

# Disable unnecessary services
sudo systemctl disable bluetooth
sudo systemctl disable cups
```

**Kiosk Mode Setup:**
```bash
# Configure auto-login and kiosk mode
sudo raspi-config nonint do_boot_behaviour B4

# Set up auto-start of streaming UI
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/rtmp-ui.desktop << EOF
[Desktop Entry]
Type=Application
Name=RTMP UI
Exec=chromium-browser --kiosk --disable-infobars http://localhost:8080
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF
```

### Creating Variants

Create specialized images for different use cases:

**Kiosk Mode Image:**
- Auto-start in full-screen UI mode
- Minimal desktop environment
- Touch-screen optimized

**Headless Image:**
- No desktop environment
- SSH enabled by default
- Web-only configuration

**Developer Image:**
- Development tools included
- Git configured
- Code editor installed

## 🚀 Automation Scripts

### Automated Image Building

Create a build script for consistent image creation:

```bash
#!/bin/bash
# build-image.sh - Automated image creation

VERSION="1.0"
BASE_IMAGE="2024-03-15-raspios-bookworm-arm64.img"

echo "🏗️  Building PI-DATV-WWATS image v${VERSION}..."

# Mount the base image
mkdir -p /tmp/pi-mount
sudo mount -o loop,offset=1048576 ${BASE_IMAGE} /tmp/pi-mount

# Chroot and install
sudo chroot /tmp/pi-mount /bin/bash << 'EOF'
# Installation commands here
cd /home/pi
git clone https://github.com/YOUR-USERNAME/PI-DATV-WWATS.git
cd PI-DATV-WWATS
./scripts/install.sh --automated
./scripts/prepare-image.sh
EOF

# Unmount and finalize
sudo umount /tmp/pi-mount

echo "✅ Image created: pi-datv-wwats-v${VERSION}.img"
```

## 📋 Quality Assurance

### Testing Checklist

Before distributing an image:

- [ ] Fresh flash boots successfully
- [ ] WiFi configuration works
- [ ] First-time setup script runs
- [ ] Camera detection works
- [ ] Streaming starts successfully
- [ ] GPIO button responds
- [ ] Web UI accessible
- [ ] HDMI preview displays
- [ ] Services auto-start on reboot

### User Feedback Integration

Track common issues and update the image:

1. Monitor user reports
2. Create fixes in the repository
3. Update image creation process
4. Release new image versions
5. Maintain changelog

## 🔄 Maintenance

### Version Management

Keep track of image versions:
- Use semantic versioning (v1.0, v1.1, etc.)
- Maintain changelog of improvements
- Tag releases in git repository
- Archive old image versions

### Update Strategy

Plan for image updates:
- **Minor updates:** Configuration and script fixes via git pull
- **Major updates:** New image releases with system updates
- **Security updates:** Emergency image releases as needed

## 📚 Resources

- [Raspberry Pi Imager](https://rpi.org/imager)
- [Win32 Disk Imager](https://sourceforge.net/projects/win32diskimager/)
- [Raspberry Pi OS Images](https://www.raspberrypi.org/software/operating-systems/)
- [WWATS Streaming Platform](https://stream.wwats.net/)

## 🆘 Troubleshooting

### Common Image Creation Issues

**Image too large:**
- Use Pi OS Lite instead of Desktop
- Remove unnecessary packages before imaging
- Use image compression

**Boot issues after flashing:**
- Verify image integrity with checksums
- Test on multiple SD cards
- Check for corrupted sectors

**Service startup problems:**
- Verify template configuration
- Check service file permissions
- Test first-time setup script

---

This process creates a professional, user-friendly deployment method that significantly reduces the barrier to entry for using the PI-DATV-WWATS system.
