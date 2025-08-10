#!/usr/bin/env bash
set -euo pipefail

# Base packages
sudo apt-get update
sudo apt-get install -y ffmpeg python3-gpiozero python3-pip v4l-utils fontconfig
sudo apt-get install -y python3-flask

# Kiosk browser (Desktop image preferred)
sudo apt-get install -y chromium || sudo apt-get install -y chromium-browser || true

# Layout
sudo mkdir -p /opt/pi-datv-wwats
sudo cp -a app/. /opt/pi-datv-wwats/

# Config
if [ ! -f /etc/rtmp-streamer.env ]; then
  sudo mkdir -p /etc
  sudo cp config/rtmp-streamer.env.sample /etc/rtmp-streamer.env
  sudo chmod 600 /etc/rtmp-streamer.env
  echo "Created /etc/rtmp-streamer.env — edit CALLSIGN/TOKEN."
fi

# Optional udev rules
if [ -f config/99-rtmp-cam.rules ]; then
  sudo cp config/99-rtmp-cam.rules /etc/udev/rules.d/
  sudo udevadm control --reload-rules || true
  sudo udevadm trigger || true
fi

# Preview script
sudo install -m 0755 scripts/preview.sh /opt/pi-datv-wwats/preview.sh

# Services
sudo install -m 0644 services/rtmp-streamer.service /etc/systemd/system/
sudo install -m 0644 services/rtmp-preview.service  /etc/systemd/system/
sudo install -m 0644 services/rtmp-ui.service       /etc/systemd/system/

# Groups / permissions
sudo usermod -aG video,audio,plugdev,render,input,gpio ${SUDO_USER:-pi} || true

# Enable services
sudo systemctl daemon-reload
sudo systemctl enable rtmp-streamer.service rtmp-preview.service rtmp-ui.service
sudo systemctl restart rtmp-ui.service rtmp-preview.service rtmp-streamer.service

# Kiosk autostart (Option B) if a desktop session exists
USER_HOME="/home/${SUDO_USER:-pi}"
if [ -d "${USER_HOME}/.config" ]; then
  install -d "${USER_HOME}/.config/autostart"
  install -m 0644 kiosk/kiosk-autostart.desktop "${USER_HOME}/.config/autostart/rtmp-ui.desktop"
  chown -R ${SUDO_USER:-pi}:${SUDO_USER:-pi} "${USER_HOME}/.config/autostart"
fi

echo
echo "Install complete. Edit /etc/rtmp-streamer.env (CALLSIGN/TOKEN) and reboot if needed."
