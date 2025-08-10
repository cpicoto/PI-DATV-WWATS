# 🎯 First-Time Setup Guide for PI-DATV-WWATS

Congratulations! You've successfully flashed the PI-DATV-WWATS image. This guide will help you complete the initial configuration to get your streaming system running.

## 🚀 Quick Start (5 Minutes)

After flashing and booting your Raspberry Pi:

1. **Connect to WiFi** using the desktop interface
2. **Open Terminal** from the desktop
3. **Run the setup script:**
   ```bash
   cd PI-DATV-WWATS
   ./scripts/first-time-setup.sh
   ```
4. **Follow the prompts** to enter your callsign and token
5. **Start streaming!** Press your GPIO button or visit http://localhost:8080

## 🔧 Detailed Setup Process

### Step 1: Hardware Verification

The image comes pre-configured for standard hardware. Verify your setup:

**Required Hardware:**
- ✅ Raspberry Pi 4B (4GB+ recommended)
- ✅ UVC USB Camera (most modern USB webcams)
- ✅ MicroSD Card (32GB+, flashed with image)

**Optional Hardware:**
- 🔘 GPIO Button (between GPIO17 and GND)
- 🔘 Status LED (GPIO27 with resistor)
- 🔘 HDMI Monitor (for local preview)

### Step 2: Network Configuration

**WiFi Setup:**
1. Click the WiFi icon in the taskbar
2. Select your network
3. Enter password
4. Wait for connection

**Ethernet:** 
- Simply connect cable - should work automatically

### Step 3: Run First-Time Setup

Open a terminal and run:

```bash
cd PI-DATV-WWATS
./scripts/first-time-setup.sh
```

**The script will:**
1. ✅ Verify system configuration
2. ✅ Check camera connectivity  
3. ✅ Prompt for your callsign
4. ✅ Prompt for your JWT token
5. ✅ Update configuration files
6. ✅ Start streaming services
7. ✅ Verify everything is working

### Step 4: Get Your JWT Token

You'll need a token from the WWATS streaming platform:

1. **Visit:** https://stream.wwats.net/
2. **Register/Login** with your amateur radio callsign
3. **Navigate** to your dashboard
4. **Copy** your streaming token
5. **Paste** when prompted by setup script

### Step 5: Verify Operation

After setup completes:

**Check System Status:**
```bash
./scripts/check-system.sh
```

**Test Streaming:**
- Press GPIO button (if connected), OR
- Open web browser to http://localhost:8080
- Click "Start Streaming"

**Verify Stream:**
- Visit https://stream.wwats.net/
- Look for your callsign in active streams

## ⚙️ Configuration Options

### Basic Settings (Most Users)

The pre-configured image works for most setups. Key settings:

```bash
# Edit configuration if needed
sudo nano /etc/rtmp-streamer.env
```

**Common Changes:**
- `RTMP_CALLSIGN=` - Your amateur radio callsign
- `RTMP_TOKEN=` - Your WWATS JWT token  
- `VIDEO_WIDTH=` - Camera resolution width (default: 1920)
- `VIDEO_HEIGHT=` - Camera resolution height (default: 1080)
- `BITRATE=` - Streaming bitrate (default: 4000k)

### Advanced Settings

**Camera Selection:**
```bash
# List available cameras
ls -l /dev/video*

# Test camera formats
ffmpeg -f v4l2 -list_formats all -i /dev/video0

# Update config if needed
sudo nano /etc/rtmp-streamer.env
# Change VIDEO_DEV=/dev/video0 to your camera
```

**GPIO Customization:**
```bash
# Default GPIO pins
BUTTON_GPIO=17  # Button between GPIO17 and GND
LED_GPIO=27     # Optional status LED

# Wire according to your setup
```

**Streaming Quality:**
```bash
# Higher quality (more bandwidth)
BITRATE=6000k
VIDEO_FPS=60

# Lower bandwidth
BITRATE=2000k
VIDEO_FPS=15

# Apply changes
sudo systemctl restart rtmp-streamer
```

## 🌐 Remote Access Setup

### Enable SSH (Optional)

For remote management:

```bash
# Enable SSH service
sudo systemctl enable ssh
sudo systemctl start ssh

# Change default password
passwd

# Find IP address
hostname -I
```

### Access Web Interface

The web control interface is available at:
- **Local:** http://localhost:8080
- **Network:** http://[PI_IP_ADDRESS]:8080

## 🚨 Troubleshooting

### Common Issues

**"Camera not detected":**
```bash
# Check USB connections
lsusb | grep -i video

# Test camera
ffmpeg -f v4l2 -i /dev/video0 -t 5 test.mp4

# Check permissions
ls -l /dev/video*
```

**"Stream won't start":**
```bash
# Check configuration
cat /etc/rtmp-streamer.env

# View detailed logs
sudo journalctl -u rtmp-streamer -f

# Restart service
sudo systemctl restart rtmp-streamer
```

**"Button not responding":**
```bash
# Test GPIO
python3 -c "
import gpiozero
btn = gpiozero.Button(17)
print('Press button...')
btn.wait_for_press()
print('Button pressed!')
"
```

**"No network connection":**
```bash
# Check WiFi status
iwconfig

# Restart networking
sudo systemctl restart dhcpcd

# Manual WiFi config
sudo raspi-config
```

### Diagnostic Tools

**Run full system check:**
```bash
./scripts/troubleshoot.sh
```

**Check specific service:**
```bash
sudo systemctl status rtmp-streamer
sudo systemctl status rtmp-preview
sudo systemctl status rtmp-ui
```

**View live logs:**
```bash
sudo journalctl -u rtmp-streamer -f
```

## 🔄 System Maintenance

### Regular Updates

Keep your system updated:

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Update PI-DATV-WWATS code
cd PI-DATV-WWATS
git pull origin main

# Restart services if code updated
sudo systemctl restart rtmp-streamer rtmp-preview rtmp-ui
```

### Backup Configuration

Save your settings:

```bash
# Backup configuration
cp /etc/rtmp-streamer.env ~/rtmp-config-backup.env

# Restore if needed
sudo cp ~/rtmp-config-backup.env /etc/rtmp-streamer.env
sudo systemctl restart rtmp-streamer
```

## 🎯 Next Steps

### Kiosk Mode Setup

For dedicated streaming appliance:

```bash
# Set up auto-login
sudo raspi-config
# Choose: Boot Options > Desktop / CLI > Desktop Autologin

# Configure auto-start streaming UI
mkdir -p ~/.config/autostart
cat > ~/.config/autostart/rtmp-ui.desktop << EOF
[Desktop Entry]
Type=Application
Name=RTMP Streaming UI
Exec=chromium-browser --kiosk --disable-infobars http://localhost:8080
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF
```

### Performance Tuning

Optimize for your specific use case:

```bash
# GPU memory for encoding
echo "gpu_mem=128" | sudo tee -a /boot/config.txt

# Disable unnecessary services
sudo systemctl disable bluetooth
sudo systemctl disable cups

# Reboot to apply
sudo reboot
```

### Custom Overlays

Add text overlays to your stream:

```bash
# Edit configuration
sudo nano /etc/rtmp-streamer.env

# Add filter (example)
VF_FILTER=drawtext=text='CALLSIGN TEST':fontfile=/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf:fontsize=24:fontcolor=white:x=10:y=10

# Restart streaming
sudo systemctl restart rtmp-streamer
```

## 🆘 Getting Help

### Self-Help Resources

1. **Run diagnostics:** `./scripts/troubleshoot.sh`
2. **Check logs:** `sudo journalctl -u rtmp-streamer -n 50`
3. **Review README:** See main project documentation
4. **Test hardware:** Use check-system.sh script

### Community Support

- **GitHub Issues:** Report bugs and request features
- **WWATS Platform:** Check service status and announcements
- **Amateur Radio Forums:** Community discussions and tips

### Reporting Issues

When asking for help, include:
- Output from `./scripts/troubleshoot.sh`
- Relevant log entries from `journalctl`
- Description of what you expected vs. what happened
- Hardware configuration details

## ✅ Success Checklist

Your system is properly configured when:

- [ ] Camera detected and working
- [ ] Stream starts without errors
- [ ] Video appears on WWATS platform
- [ ] GPIO button controls work (if connected)
- [ ] Web interface responds
- [ ] Services auto-start after reboot
- [ ] HDMI preview displays (if connected)

**🎉 Congratulations! Your PI-DATV-WWATS system is ready to stream!**

---

For advanced configuration and development information, see the main [README.md](README.md) file.
