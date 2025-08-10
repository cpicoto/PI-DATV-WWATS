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
├── README.md
├── HOWTO-install.md
├── app/
│   ├── streammer.py             # GPIO + FFmpeg + tee + reconnect + status overlay
│   └── rtmp-ui.py               # Flask Start/Stop web UI
├── config/
│   ├── rtmp-streamer.env.sample # example config copied to /etc/rtmp-streamer.env
│   └── 99-rtmp-cam.rules        # optional udev stable device names
├── scripts/
│   ├── install.sh               # installs packages, files, and systemd services
│   └── preview.sh               # split-screen HDMI renderer (ffplay lavfi)
├── services/
│   ├── rtmp-streamer.service    # capture/encode/push
│   ├── rtmp-preview.service     # HDMI compositor
│   └── rtmp-ui.service          # Flask UI
└── kiosk/
    └── kiosk-autostart.desktop  # Chromium kiosk autostart
```

## Quick Start (Fresh Pi)

> **Note:** Desktop image is recommended for kiosk UI. Lite also works, but you'll need a browser if you want on-device mouse control.

### 1. Install Prerequisites and Clone

```bash
sudo apt-get update && sudo apt-get install -y git
git clone https://github.com/cpicoto/PI-DATV-WWATS.git
cd PI-DATV-WWATS
```

### 2. Run the Installer

```bash
sudo ./scripts/install.sh
```

### 3. Configure Your Identity and Options

```bash
sudo nano /etc/rtmp-streamer.env
```

Set at least:
```bash
RTMP_CALLSIGN=AD7NP
RTMP_TOKEN=REPLACE_WITH_YOUR_JWT
ENCODER=h264_v4l2m2m    # or libx264 for software encoding
VIDEO_INPUT_FORMAT=mjpeg  # mjpeg, yuyv422, or leave blank to auto
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

---

**Author:** Carlos Picoto (AD7NP)  
**License:** MIT