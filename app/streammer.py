#!/usr/bin/env python3
import os
import signal
import subprocess
import sys
import time
from pathlib import Path
from gpiozero import Button, LED

CONFIG_PATH = "/etc/rtmp-streamer.env"
STATUS_PATH = "/run/rtmp-status.txt"

class Env:
    def __init__(self, path):
        self._vals = {}
        for line in Path(path).read_text().splitlines():
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            k, _, v = line.partition('=')
            self._vals[k.strip()] = v.strip()
    def get(self, k, default=None):
        return self._vals.get(k, default)

def build_rtmp_url(env: Env) -> str:
    base = env.get('RTMP_BASE')
    cs = env.get('RTMP_CALLSIGN')
    tok = env.get('RTMP_TOKEN')
    if not (base and cs and tok):
        print("ERROR: Missing RTMP_BASE, RTMP_CALLSIGN or RTMP_TOKEN in /etc/rtmp-streamer.env")
        sys.exit(2)
    return f"{base}/{cs}?token={tok}"

def build_ffmpeg_cmd(env: Env):
    video = env.get('VIDEO_DEV', '/dev/video0')
    width = env.get('VIDEO_WIDTH', '1280')
    height = env.get('VIDEO_HEIGHT', '720')
    fps = env.get('VIDEO_FPS', '30')
    a_dev = env.get('AUDIO_DEV', 'default')
    a_rate = env.get('AUDIO_RATE', '48000')
    bitrate = env.get('BITRATE', '2500k')
    gop = env.get('GOP_SECONDS', '2')
    profile = env.get('PROFILE', 'high')
    vf = env.get('VF_FILTER', '')

    # Build final RTMP URL
    rtmp = build_rtmp_url(env)

    # Encoder selection (Pi does the H.264 encoding; camera is UVC only)
    #   'h264_v4l2m2m' -> Pi hardware encoder (Pi 4/5)
    #   'libx264'      -> software encoder on CPU
    encoder = (env.get('ENCODER', 'h264_v4l2m2m') or 'h264_v4l2m2m').strip()

    # Optional explicit camera input format (many UVC cams default to mjpeg or yuyv422)
    in_fmt = (env.get('VIDEO_INPUT_FORMAT', '') or '').strip()

    # Local tee preview
    enable_tee = env.get('ENABLE_TEE_PREVIEW', '0') == '1'
    preview_url = env.get('PREVIEW_UDP_URL', 'udp://127.0.0.1:23000?pkt_size=1316')

    cmd = [
        'ffmpeg', '-hide_banner', '-loglevel', 'warning',
        '-thread_queue_size', '1024',
        '-f', 'v4l2'
    ]
    if in_fmt:
        cmd += ['-input_format', in_fmt]
    cmd += [
        '-framerate', str(fps),
        '-video_size', f'{width}x{height}',
        '-i', video,
        '-thread_queue_size', '1024',
        '-f', 'alsa', '-ar', str(a_rate), '-i', a_dev
    ]

    # Video encoder config (on the Pi)
    if encoder == 'libx264':
        # Software H.264 on CPU
        cmd += [
            '-c:v', 'libx264',
            '-preset', 'veryfast',
            '-tune', 'zerolatency',
            '-b:v', bitrate, '-maxrate', bitrate, '-bufsize', bitrate,
            '-pix_fmt', 'yuv420p',
            '-g', str(int(fps) * int(gop)),
            '-profile:v', profile
        ]
    else:
        # Default: Pi hardware H.264 via V4L2 M2M
        cmd += [
            '-c:v', 'h264_v4l2m2m',
            '-b:v', bitrate, '-maxrate', bitrate, '-bufsize', bitrate,
            '-pix_fmt', 'yuv420p',
            '-g', str(int(fps) * int(gop)),
            '-profile:v', profile
        ]

    # Audio encode (AAC)
    cmd += ['-c:a', 'aac', '-b:a', '128k', '-ac', '2']

    if vf:
        cmd += ['-vf', vf]

    # Outputs
    if enable_tee:
        tee_spec = f"[f=flv]{rtmp}|[f=mpegts]{preview_url}"
        cmd += ['-f', 'tee', tee_spec]
    else:
        cmd += ['-f', 'flv', rtmp]

    return cmd

class StreamController:
    def __init__(self, env: Env):
        self.env = env
        self.proc = None
        self.led = None
        led_gpio = int(self.env.get('LED_GPIO', '0') or '0')
        if led_gpio:
            self.led = LED(led_gpio)
            self.led.off()

    def start(self):
        if self.proc and self.proc.poll() is None:
            print("Already streaming")
            return
        cmd = build_ffmpeg_cmd(self.env)
        print("Starting ffmpeg:", ' '.join(cmd))
        self.proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        if self.led:
            self.led.on()

    def stop(self):
        if not self.proc or self.proc.poll() is not None:
            print("Not streaming")
            return
        print("Stopping stream…")
        self.proc.send_signal(signal.SIGINT)
        try:
            self.proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.proc.kill()
        self.proc = None
        if self.led:
            self.led.off()

    def toggle(self):
        if self.proc and self.proc.poll() is None:
            self.stop()
        else:
            self.start()

    def run(self):
        btn_gpio = int(self.env.get('BUTTON_GPIO', '17'))
        btn = Button(btn_gpio, pull_up=True, bounce_time=0.08)
        btn.when_pressed = lambda: self.toggle()

        reconnect_wait = int(self.env.get('RECONNECT_WAIT', '2'))
        max_reconnect = int(self.env.get('MAX_RECONNECT', '0'))
        attempts = 0

        try:
            while True:
                # status overlay file
                width = self.env.get('VIDEO_WIDTH', '1280')
                height = self.env.get('VIDEO_HEIGHT', '720')
                fps = self.env.get('VIDEO_FPS', '30')
                bitrate = self.env.get('BITRATE', '2500k')
                gop = self.env.get('GOP_SECONDS', '2')
                video = self.env.get('VIDEO_DEV', '/dev/video0')
                a_dev = self.env.get('AUDIO_DEV', 'default')
                rtmp = build_rtmp_url(self.env)
                state = 'ON' if (self.proc and self.proc.poll() is None) else 'OFF'
                try:
                    with open(STATUS_PATH, 'w') as f:
                        f.write(
                            f"State: {state}  |  {width}x{height}@{fps}  |  BR={bitrate}  |  GOP={gop}s\n"
                            f"Video: {video}  |  Audio: {a_dev}  |  RTMP: {rtmp[:80]}...\n"
                            f"Press button (GPIO{btn_gpio}) or use the UI to toggle\n"
                        )
                except Exception:
                    pass

                # auto-reconnect if process died while ON
                if self.proc:
                    rc = self.proc.poll()
                    if rc is not None:
                        attempts += 1
                        if self.led:
                            self.led.blink(on_time=0.2, off_time=0.8)
                        if max_reconnect and attempts > max_reconnect:
                            print("Max reconnect attempts reached; stopping.")
                            self.proc = None
                            if self.led:
                                self.led.off()
                        else:
                            print(f"ffmpeg exited (rc={rc}). Reconnecting in {reconnect_wait}s…")
                            time.sleep(reconnect_wait)
                            self.start()
                    else:
                        attempts = 0
                time.sleep(0.2)
        except KeyboardInterrupt:
            pass
        finally:
            self.stop()

def main():
    env = Env(CONFIG_PATH)
    ctl = StreamController(env)
    def _sigterm(signum, frame):
        ctl.stop()
