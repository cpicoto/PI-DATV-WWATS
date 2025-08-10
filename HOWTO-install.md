# PI-DATV-WWATS — Install

This sets up a Raspberry Pi (Bookworm) as a one-button + mouse UI RTMP encoder with split-screen HDMI preview.

## 1) Prereqs
- Raspberry Pi 4/5 (Bookworm). Desktop image recommended (for kiosk); Lite also works.
- USB UVC camera (1080p) with built-in mic.
- GPIO wiring:
  - Button: GPIO17 (pin 11) → GND (pin 9)
  - LED (optional): GPIO27 (pin 13) → resistor → LED → GND

## 2) Clone and install
```bash
sudo apt-get update && sudo apt-get install -y git
git clone https://github.com/cpicoto/PI-DATV-WWATS.git
cd PI-DATV-WWATS
sudo ./scripts/install.sh
