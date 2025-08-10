# 💾 Flashing Instructions for PI-DATV-WWATS Pre-configured Image

## 📋 What You'll Need

- **Raspberry Pi 4B** (4GB+ RAM recommended)
- **MicroSD Card** (32GB+ Class 10 or better)
- **SD Card Reader** for your computer
- **UVC USB Camera** (most modern USB webcams work)
- **Computer** (Windows, macOS, or Linux)

## 🔽 Download Required Software

### Raspberry Pi Imager (Recommended)
- **Download:** https://rpi.org/imager
- **Platforms:** Windows, macOS, Linux
- **Why:** Easiest method, built-in verification

### Alternative: Win32 Disk Imager (Windows Only)
- **Download:** https://sourceforge.net/projects/win32diskimager/
- **Platform:** Windows only
- **When:** If you prefer traditional imaging tools

## 📱 Flashing Steps

### Method 1: Raspberry Pi Imager (Easiest)

1. **Install Raspberry Pi Imager**
   - Download and install from link above
   - Launch the application

2. **Select Image**
   - Click "Choose OS"
   - Select "Use custom" 
   - Browse to your downloaded `pi-datv-wwats-v1.0.img.gz` file

3. **Select SD Card**
   - Insert your SD card
   - Click "Choose Storage"
   - Select your SD card (be careful to pick the right one!)

4. **Configure (Optional)**
   - Click the gear icon ⚙️ for advanced options
   - **Enable SSH** (if you want remote access)
   - **Set username/password** (optional)
   - **Configure WiFi** (saves time on first boot)

5. **Flash the Image**
   - Click "Write"
   - Confirm you've selected the correct SD card
   - Wait for flashing and verification to complete (10-20 minutes)

### Method 2: Win32 Disk Imager (Windows)

1. **Decompress Image** (if .gz file)
   - Extract `pi-datv-wwats-v1.0.img.gz` 
   - You should have `pi-datv-wwats-v1.0.img`

2. **Launch Win32 Disk Imager**
   - Run as Administrator
   - Insert SD card

3. **Select Image and Device**
   - Browse to select your `.img` file
   - Choose the correct SD card drive letter
   - **Double-check the drive letter!**

4. **Write Image**
   - Click "Write"
   - Confirm overwrite warning
   - Wait for completion

## 🔌 Hardware Setup

### Basic Connections
1. **Insert SD Card** into Raspberry Pi 4B
2. **Connect USB Camera** to any USB port
3. **Connect HDMI Monitor** (optional, for preview)
4. **Connect GPIO Button** (optional):
   - Button between GPIO17 (pin 11) and GND (pin 14)
   - See wiring diagram in main README

### First Boot
1. **Power On** the Raspberry Pi
2. **Wait for boot** (first boot takes 2-3 minutes)
3. **Connect to WiFi** using desktop interface
4. **Open Terminal** from desktop

## ⚙️ First-Time Configuration

### Run Setup Script
```bash
cd PI-DATV-WWATS
./scripts/first-time-setup.sh
```

The script will prompt you for:
- **Your Callsign** (amateur radio callsign)
- **JWT Token** (from WWATS platform)

### Get Your JWT Token
1. Visit: https://stream.wwats.net/
2. Log in or register
3. Navigate to your dashboard
4. Copy your streaming token

## ✅ Verification

### Check System Status
```bash
# Run system check
./scripts/check-system.sh

# Check streaming service
sudo systemctl status rtmp-streamer
```

### Test Streaming
1. **Press GPIO button** (if connected) OR
2. **Open web interface** at http://localhost:8080
3. **Verify stream** at https://stream.wwats.net/

## 🚨 Troubleshooting

### SD Card Not Detected
- Try a different SD card reader
- Verify SD card isn't locked (switch on side)
- Use a different SD card (some are incompatible)

### Flashing Fails
- **Check available space** (need 8GB+ free)
- **Try different USB port** for SD card reader
- **Run as Administrator** (Windows)
- **Verify image download** isn't corrupted

### Pi Won't Boot
- **Check power supply** (need 3A+ for Pi 4B)
- **Verify SD card** in multiple devices
- **Try different SD card** (some brands have issues)
- **Check HDMI connection** (might be booting but no display)

### No Camera Detected
```bash
# List USB devices
lsusb

# Check video devices
ls -l /dev/video*

# Test camera
ffmpeg -f v4l2 -list_formats all -i /dev/video0
```

### Services Not Starting
```bash
# Check logs
sudo journalctl -u rtmp-streamer -f

# Restart services
sudo systemctl restart rtmp-streamer

# Check configuration
cat /etc/rtmp-streamer.env
```

## 📞 Getting Help

### Check These First
1. **Run diagnostics:** `./scripts/troubleshoot.sh`
2. **Check logs:** `sudo journalctl -u rtmp-streamer -n 50`
3. **Verify config:** `cat /etc/rtmp-streamer.env`

### Community Support
- **GitHub Issues:** https://github.com/YOUR-USERNAME/PI-DATV-WWATS/issues
- **WWATS Discord:** [Link to Discord server]
- **Amateur Radio Forums:** [Links to relevant forums]

### Reporting Issues
Include this information:
- Raspberry Pi model and RAM
- SD card brand/size
- Camera model
- Error messages from logs
- Output of `./scripts/troubleshoot.sh`

## 🎉 Success!

Once setup is complete, your system will:
- ✅ Start streaming automatically on boot
- ✅ Respond to GPIO button presses
- ✅ Display preview on HDMI (if connected)
- ✅ Provide web control interface
- ✅ Reconnect automatically if network drops

**Happy Streaming! 📡**

---

For advanced configuration and troubleshooting, see the main [README.md](README.md) and [IMAGE-CREATION.md](IMAGE-CREATION.md) files.
