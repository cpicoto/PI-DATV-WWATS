# PI-DATV-WWATS

A Raspberry Pi–based one-button + web UI **RTMP streaming station** for WWATS.

## Features

- **Camera:** Any UVC-compatible USB webcam (video + mic). The camera does not encode H.264.
- **Encoding:** All H.264 video and AAC audio encoding is done **on the Raspberry Pi** via FFmpeg, using either the Pi's hardware encoder (`h264_v4l2m2m`) or the software encoder (`libx264`).
- **Preview:** HDMI split-screen with live overlay — 
  - **Left:** your local encoded feed
  - **Right:** fixed remote URL (`https://stream.wwats.net/`)
- **Control:** Physical **GPIO button** *and* mouse-click **web UI** in **Chromium kiosk**.
- **Reliability:** `systemd` services, auto-start on boot, reconnect logic.

## How it works (high level)

1. FFmpeg captures video (`/dev/videoX`) and audio (ALSA) from your USB webcam.
2. The Pi **encodes** H.264 (`h264_v4l2m2m` or `libx264`) + AAC and **pushes** to:
   ```
   rtmp://streaming.wwats.net/live/<CALLSIGN>?token=<TOKEN>
   ```
3. A **tee** output also feeds a local UDP preview used to render the **split-screen HDMI** (local | remote).
4. A tiny Flask web app exposes **Start/Stop** buttons and displays status on the kiosk page.
5. A GPIO button toggles streaming in parallel with the UI.

## Hardware Requirements

- Raspberry Pi 4 or 5 (Raspberry Pi OS **Bookworm** recommended)
- USB UVC webcam (1080p capable) with built-in mic (or separate USB mic)
- Reliable 5V power supply
- **Button:** GPIO17 (pin 11) → GND (pin 9)
- **LED (optional):** GPIO27 (pin 13) → resistor → LED → GND
- HDMI display + USB mouse (for kiosk UI)

---

## Repository Layout

```
PI-DATV-WWATS/
├── LICENSE
├── .gitignore
├── README.md                    # This file - comprehensive project guide
├── HOWTO-install.md            # Detailed installation instructions
├── IMAGE-CREATION.md           # Pre-configured image creation guide
├── FLASH-INSTRUCTIONS.md       # User guide for flashing pre-made images
├── FIRST-TIME-SETUP.md         # Post-flash configuration guide
├── app/
│   ├── streamer.py              # GPIO + FFmpeg + tee + reconnect + status overlay
│   └── rtmp-ui.py               # Flask Start/Stop web UI
├── config/
│   ├── rtmp-streamer.env.sample # example config copied to /etc/rtmp-streamer.env
│   ├── rtmp-streamer.env.template # template config for pre-configured images
│   └── 99-rtmp-cam.rules        # optional udev stable device names
├── scripts/
│   ├── install.sh               # installs packages, files, and systemd services
│   ├── check-system.sh          # pre-installation system check
│   ├── troubleshoot.sh          # troubleshooting and diagnostics
│   ├── first-time-setup.sh      # interactive setup for pre-configured images
│   ├── prepare-image.sh         # prepares system for image distribution
│   └── preview.sh               # split-screen HDMI renderer (ffplay lavfi)
├── services/
│   ├── rtmp-streamer.service    # capture/encode/push
│   ├── rtmp-preview.service     # HDMI compositor
│   └── rtmp-ui.service          # Flask UI
└── kiosk/
    └── kiosk-autostart.desktop  # Chromium kiosk autostart
```

## Hardware Setup Guide

### Basic Wiring

1. **Power**: Use a quality 5V power supply (3A+ recommended)
2. **Camera**: Connect UVC-compatible USB camera with built-in microphone
3. **Button**: Connect momentary push button:
   - One side to **GPIO17** (Physical pin 11)
   - Other side to **GND** (Physical pin 9)
4. **LED (Optional)**: Connect status LED:
   - **Anode (+)** → **330Ω resistor** → **GPIO27** (Physical pin 13)
   - **Cathode (-)** → **GND** (Physical pin 14)
5. **Display**: Connect HDMI monitor for split-screen preview

### Recommended Hardware

- **Raspberry Pi 4B or 5** (4GB+ RAM recommended)
- **UVC USB Camera**: Logitech C920, C922, or similar 1080p camera
- **MicroSD Card**: 32GB+ Class 10 or better
- **Power Supply**: Official Raspberry Pi power adapter
- **Case**: With proper ventilation and GPIO access
- **Button**: Momentary tactile switch
- **LED**: Standard 5mm LED with 330Ω resistor

## 🚀 Two Ways to Get Started

### Option 1: Pre-configured Image (Easiest - 5 Minutes)

**Best for:** Users who want to get streaming quickly with minimal setup.

1. **Download** the pre-configured image (when available)
2. **Flash** to SD card using Raspberry Pi Imager
3. **Boot** your Pi and connect to WiFi
4. **Run setup:** `./scripts/first-time-setup.sh`
5. **Enter** your callsign and JWT token
6. **Start streaming!**

📖 **Detailed Guide:** See [FLASH-INSTRUCTIONS.md](FLASH-INSTRUCTIONS.md) for complete flashing and setup instructions.

### Option 2: Manual Installation (Custom Setup)

**Best for:** Users who want to customize their installation or learn the process.

## Quick Start (Fresh Pi)

> **Note:** Desktop image is recommended for kiosk UI. Lite also works, but you'll need a browser if you want on-device mouse control.

### 1. Pre-Installation Check (Recommended)

```bash
sudo apt-get update && sudo apt-get install -y git
git clone https://github.com/cpicoto/PI-DATV-WWATS.git
cd PI-DATV-WWATS
./scripts/check-system.sh
```

This will verify your system meets the requirements.

### 2. Run the Installer

```bash
sudo ./scripts/install.sh
```

The installer will:
- Install all required packages (ffmpeg, python3-gpiozero, etc.)
- Create application directories
- Set up systemd services
- Configure user permissions
- Set up kiosk autostart (if desktop available)

### 3. Configure Your Identity and Options

```bash
sudo nano /etc/rtmp-streamer.env
```

**Required settings:**
```bash
RTMP_CALLSIGN=YOUR_CALLSIGN    # Replace with your amateur radio callsign
RTMP_TOKEN=YOUR_JWT_TOKEN      # Replace with your JWT token from WWATS
```

**Optional but recommended:**
```bash
ENCODER=h264_v4l2m2m          # Use hardware encoder (Pi 4/5)
VIDEO_INPUT_FORMAT=mjpeg      # For better camera compatibility
VIDEO_WIDTH=1920              # Adjust based on your camera/bandwidth
VIDEO_HEIGHT=1080
BITRATE=4000k                 # Adjust based on your upload bandwidth
```

Then protect the file:
```bash
sudo chmod 600 /etc/rtmp-streamer.env
```

### 4. Reboot

```bash
sudo reboot
```

### After Boot

- The **Chromium kiosk** opens at `http://localhost:8080` with big **Start/Stop** buttons
- The **HDMI** shows split-screen (local | `https://stream.wwats.net/`) with a live text overlay
- The **GPIO button** (GPIO17) toggles streaming

### Troubleshooting

If something doesn't work, run the troubleshooting script:
```bash
./scripts/troubleshoot.sh
```

## Configuration (All Keys)

Edit `/etc/rtmp-streamer.env` to adjust behavior:

```bash
# ===== WWATS PI-DATV CONFIG =====
# RTMP destination (assembled at runtime)
RTMP_BASE=rtmp://streaming.wwats.net/live
RTMP_CALLSIGN=AD7NP
RTMP_TOKEN=REPLACE_WITH_YOUR_JWT

# Video input (UVC camera)
VIDEO_DEV=/dev/video0
VIDEO_WIDTH=1920
VIDEO_HEIGHT=1080
VIDEO_FPS=30

# Some UVC cams prefer a specific input format; leave blank if unsure:
# mjpeg | yuyv422 | (blank = let FFmpeg decide)
VIDEO_INPUT_FORMAT=mjpeg

# Audio input (ALSA)
AUDIO_DEV=default
AUDIO_RATE=48000

# GPIO pins
BUTTON_GPIO=17
LED_GPIO=27

# Encoding on the Pi (camera provides raw/MJPEG/YUYV only)
# h264_v4l2m2m = hardware H.264 (Pi 4/5 VideoCore)
# libx264      = software H.264 (CPU)
ENCODER=h264_v4l2m2m
BITRATE=4000k
GOP_SECONDS=2
PROFILE=high
VF_FILTER=

# Local preview tee for HDMI compositor
ENABLE_TEE_PREVIEW=1
PREVIEW_UDP_URL=udp://127.0.0.1:23000?pkt_size=1316

# Split-screen remote monitor (right side)
REMOTE_URL=https://stream.wwats.net/
SCREEN_W=1920
SCREEN_H=1080
OVERLAY_FONT=/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf

# Web UI
ENABLE_UI=1
UI_PORT=8080

# Reconnect policy
RECONNECT_WAIT=2
MAX_RECONNECT=0   # 0 = infinite
```

> **Security:** The token is sensitive — keep `/etc/rtmp-streamer.env` at `chmod 600`.

## Using the System

### Start / Stop

- **Mouse:** Click **Start** / **Stop** in the kiosk UI on HDMI (Chromium)
- **GPIO:** Press the physical button on GPIO17 to toggle

### HDMI Preview

- **Left:** Your locally encoded feed (no second encode)
- **Right:** `https://stream.wwats.net/`
- **Bottom overlay:** Shows state, resolution, fps, bitrate, device names, and a truncated RTMP URL

### LAN Access

Open the UI from another device:
```
http://<pi-ip>:8080
```

## Change Settings

### Encoder

Switch between hardware and software encoding:
```bash
ENCODER=h264_v4l2m2m   # low CPU (Pi 4/5)
# or
ENCODER=libx264        # software, higher CPU
```

Then:
```bash
sudo systemctl restart rtmp-streamer
```

### Resolution / FPS / Bitrate

Adjust:
```bash
VIDEO_WIDTH=1920
VIDEO_HEIGHT=1080
VIDEO_FPS=30
BITRATE=4000k
```

Then:
```bash
sudo systemctl restart rtmp-streamer
```

### Remote (Right Side) URL

Set:
```bash
REMOTE_URL=https://stream.wwats.net/
```

Then:
```bash
sudo systemctl restart rtmp-preview
```

## Services and Logs

### Services

- `rtmp-streamer.service` — capture, encode, tee, and push RTMP
- `rtmp-preview.service` — HDMI split-screen compositor with overlay
- `rtmp-ui.service` — Flask web UI (Start/Stop), used by kiosk

Enable at boot:
```bash
sudo systemctl enable rtmp-streamer rtmp-preview rtmp-ui
```

Start/stop/status:
```bash
sudo systemctl start rtmp-streamer
sudo systemctl stop rtmp-streamer
systemctl status rtmp-streamer
```

### Logs

Follow logs:
```bash
sudo journalctl -u rtmp-streamer -f
sudo journalctl -u rtmp-preview -f
sudo journalctl -u rtmp-ui -f
```

## Troubleshooting

### Detect Devices

List video:
```bash
v4l2-ctl --list-devices
```

List audio:
```bash
arecord -l
arecord -L
```

If needed, set `AUDIO_DEV=plughw:1,0` (example) in `/etc/rtmp-streamer.env`.

### No Video / Device Busy

- Verify `VIDEO_DEV` (often `/dev/video0`)
- Try a powered USB hub for power-hungry cameras
- Set `VIDEO_INPUT_FORMAT=mjpeg` or `yuyv422` if default fails

### Audio Out of Sync

- Keep `VIDEO_FPS` stable (e.g., 30)
- Consider reducing resolution or using hardware encoder

## Uninstall

```bash
sudo systemctl disable --now rtmp-preview rtmp-ui rtmp-streamer
sudo rm -f /etc/systemd/system/rtmp-{preview,ui,streamer}.service
sudo rm -rf /opt/pi-datv-wwats /etc/rtmp-streamer.env /etc/udev/rules.d/99-rtmp-cam.rules
```

## 📚 Additional Documentation

### For Users
- **[FLASH-INSTRUCTIONS.md](FLASH-INSTRUCTIONS.md)** - Complete guide for flashing and setting up pre-configured images
- **[FIRST-TIME-SETUP.md](FIRST-TIME-SETUP.md)** - Detailed post-flash configuration instructions
- **[HOWTO-install.md](HOWTO-install.md)** - Advanced manual installation guide

### For Developers and Image Creators
- **[IMAGE-CREATION.md](IMAGE-CREATION.md)** - Complete guide for creating and distributing pre-configured images
- Includes automated image preparation scripts
- Distribution packaging instructions
- Quality assurance checklists

## 🤝 Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Test your changes thoroughly
4. Submit a pull request with detailed description

### Reporting Issues
When reporting problems, please include:
- Output from `./scripts/troubleshoot.sh`
- Relevant log entries from `journalctl`
- Hardware configuration details
- Steps to reproduce the issue

---

**Author:** Carlos Picoto (AD7NP)  
**License:** MIT