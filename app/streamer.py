#!/usr/bin/env python3
"""
PI-DATV-WWATS Streamer
A Raspberry Pi RTMP streaming controller with GPIO button support.
"""
import os
import signal
import subprocess
import sys
import time
import logging
from pathlib import Path
from gpiozero import Button, LED, GPIOPinInUse

CONFIG_PATH = "/etc/rtmp-streamer.env"
STATUS_PATH = "/home/datv/rtmp-status.txt"
COMMAND_PATH = "/home/datv/rtmp-command.txt"

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class Env:
    def __init__(self, path):
        self._vals = {}
        if not os.path.exists(path):
            raise FileNotFoundError(f"Configuration file not found: {path}")
        
        try:
            for line in Path(path).read_text().splitlines():
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                k, _, v = line.partition('=')
                self._vals[k.strip()] = v.strip()
        except Exception as e:
            raise RuntimeError(f"Error reading config file {path}: {e}")
    
    def get(self, k, default=None):
        return self._vals.get(k, default)
    
    def validate_required(self):
        """Validate that required configuration keys are present."""
        required_keys = ['RTMP_BASE', 'RTMP_CALLSIGN', 'RTMP_TOKEN']
        missing = [k for k in required_keys if not self.get(k)]
        if missing:
            raise ValueError(f"Missing required configuration keys: {', '.join(missing)}")

def build_rtmp_url(env: Env) -> str:
    env.validate_required()
    base = env.get('RTMP_BASE')
    cs = env.get('RTMP_CALLSIGN')
    tok = env.get('RTMP_TOKEN')
    return f"{base}/{cs}?token={tok}"

def build_ffmpeg_cmd(env: Env):
    """Build FFmpeg command with optimized low-latency settings (your proven command)."""
    # Validate required parameters
    video = env.get('VIDEO_DEV', '/dev/video0')
    if not os.path.exists(video):
        logger.warning(f"Video device {video} not found")
    
    width = env.get('VIDEO_WIDTH', '1280')
    height = env.get('VIDEO_HEIGHT', '720')
    fps = env.get('VIDEO_FPS', '15')
    a_rate = env.get('AUDIO_RATE', '48000')
    bitrate = env.get('BITRATE', '2M')  # Use your proven 2M bitrate
    
    # Build final RTMP URL
    rtmp = build_rtmp_url(env)
    
    # Local tee preview
    enable_tee = env.get('ENABLE_TEE_PREVIEW', '0') == '1'
    preview_url = env.get('PREVIEW_UDP_URL', 'udp://127.0.0.1:23000?pkt_size=1316')
    
    # Use your exact proven FFmpeg command structure
    cmd = [
        'ffmpeg',
        '-y',  # Overwrite output files
        
        # Video input with your optimizations
        '-f', 'v4l2',
        '-thread_queue_size', '4096',
        '-input_format', 'mjpeg',
        '-video_size', f'{width}x{height}',
        '-framerate', str(fps),
        '-i', video,
        
        # Audio input - null source (your proven approach)
        '-f', 'lavfi',
        '-i', f'anullsrc=channel_layout=stereo:sample_rate={a_rate}',
        
        # Video encoding with your proven x264 settings
        '-c:v', 'libx264',
        '-preset', 'ultrafast',
        '-tune', 'zerolatency',
        '-profile:v', 'baseline',
        '-level:v', '3.0',
        '-pix_fmt', 'yuv420p',
        '-g', '30',
        '-keyint_min', '30',
        '-sc_threshold', '0',
        '-b:v', bitrate,
        '-maxrate', '2.2M',
        '-bufsize', '1M',
        '-x264-params', 'keyint=30:min-keyint=30:scenecut=0:rc-lookahead=0:sliced-threads=1:sync-lookahead=0:me=dia:subme=1:me_range=4:partitions=none:weightb=0:weightp=0:8x8dct=0:fast-pskip=1:mixed-refs=0:trellis=0:chroma-me=0',
        
        # Audio encoding
        '-c:a', 'aac',
        '-b:a', '128k',
        '-ar', str(a_rate),
        '-ac', '2'
    ]
    
    # Output with your proven tee structure
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
        
        # Set up LED if configured
        led_gpio = int(self.env.get('LED_GPIO', '0') or '0')
        if led_gpio:
            try:
                self.led = LED(led_gpio)
                self.led.off()
                logger.info(f"LED initialized on GPIO{led_gpio}")
            except Exception as e:
                logger.warning(f"Could not initialize LED on GPIO{led_gpio}: {e}")

    def start(self):
        """Start the streaming process."""
        if self.proc and self.proc.poll() is None:
            logger.info("Already streaming")
            return
        
        try:
            cmd = build_ffmpeg_cmd(self.env)
            logger.info(f"Starting ffmpeg with command: {' '.join(cmd)}")  # Log full command
            self.proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            logger.info(f"Started streaming process with PID {self.proc.pid}")
            
            if self.led:
                self.led.on()
        except Exception as e:
            logger.error(f"Failed to start streaming: {e}")
            self.proc = None

    def stop(self):
        """Stop the streaming process."""
        if not self.proc or self.proc.poll() is not None:
            logger.info("Not streaming")
            return
        
        try:
            logger.info("Stopping stream...")
            self.proc.send_signal(signal.SIGINT)
            try:
                self.proc.wait(timeout=5)
                logger.info("Stream stopped gracefully")
            except subprocess.TimeoutExpired:
                logger.warning("Stream didn't stop gracefully, killing...")
                self.proc.kill()
                self.proc.wait()
            
            self.proc = None
            if self.led:
                self.led.off()
        except Exception as e:
            logger.error(f"Error stopping stream: {e}")

    def toggle(self):
        """Toggle streaming on/off."""
        if self.proc and self.proc.poll() is None:
            self.stop()
        else:
            self.start()

    def _update_status_file(self, btn_gpio):
        """Update the status overlay file."""
        try:
            width = self.env.get('VIDEO_WIDTH', '1280')
            height = self.env.get('VIDEO_HEIGHT', '720')
            fps = self.env.get('VIDEO_FPS', '30')
            bitrate = self.env.get('BITRATE', '2500k')
            gop = self.env.get('GOP_SECONDS', '2')
            video = self.env.get('VIDEO_DEV', '/dev/video0')
            a_dev = self.env.get('AUDIO_DEV', 'default')
            rtmp = build_rtmp_url(self.env)
            state = 'ON' if (self.proc and self.proc.poll() is None) else 'OFF'
            
            with open(STATUS_PATH, 'w') as f:
                f.write(
                    f"State: {state}  |  {width}x{height}@{fps}  |  BR={bitrate}  |  GOP={gop}s\n"
                    f"Video: {video}  |  Audio: {a_dev}  |  RTMP: {rtmp[:80]}...\n"
                    f"Press button (GPIO{btn_gpio}) or use the UI to toggle\n"
                )
        except Exception as e:
            logger.warning(f"Could not update status file: {e}")

    def _check_web_commands(self):
        """Check for commands from the web UI."""
        try:
            if os.path.exists(COMMAND_PATH):
                with open(COMMAND_PATH, 'r') as f:
                    command = f.read().strip().lower()
                
                # Remove the command file
                os.unlink(COMMAND_PATH)
                
                if command == 'start':
                    logger.info("Received START command from web UI")
                    self.start()
                elif command == 'stop':
                    logger.info("Received STOP command from web UI")
                    self.stop()
                elif command == 'toggle':
                    logger.info("Received TOGGLE command from web UI")
                    self.toggle()
                    
        except PermissionError as e:
            # Log permission errors for debugging
            logger.warning(f"Permission error on command file: {e}")
        except Exception as e:
            logger.warning(f"Error checking web commands: {e}")

    def run(self):
        """Main run loop with GPIO button handling."""
        btn_gpio = int(self.env.get('BUTTON_GPIO', '17'))
        btn = None
        
        try:
            # Set up GPIO button
            btn = Button(btn_gpio, pull_up=True, bounce_time=0.08)
            btn.when_pressed = lambda: self.toggle()
            logger.info(f"GPIO button initialized on pin {btn_gpio}")
        except Exception as e:
            logger.error(f"Could not initialize GPIO button on pin {btn_gpio}: {e}")
            logger.info("Continuing without GPIO button support")

        reconnect_wait = int(self.env.get('RECONNECT_WAIT', '2'))
        max_reconnect = int(self.env.get('MAX_RECONNECT', '0'))
        attempts = 0

        logger.info("Streamer started. Press Ctrl+C to exit.")
        
        try:
            while True:
                # Check for commands from web UI
                self._check_web_commands()
                
                # Update status overlay file
                self._update_status_file(btn_gpio)

                # Auto-reconnect if process died while supposed to be running
                if self.proc:
                    rc = self.proc.poll()
                    if rc is not None:
                        attempts += 1
                        
                        # Capture FFmpeg error output
                        try:
                            stdout, stderr = self.proc.communicate(timeout=1)
                            if stdout:
                                logger.error(f"FFmpeg stdout: {stdout.decode('utf-8', errors='ignore')}")
                            if stderr:
                                logger.error(f"FFmpeg stderr: {stderr.decode('utf-8', errors='ignore')}")
                        except subprocess.TimeoutExpired:
                            logger.warning("Timeout while reading FFmpeg output")
                        except Exception as e:
                            logger.warning(f"Error reading FFmpeg output: {e}")
                        
                        logger.warning(f"ffmpeg exited with code {rc}")
                        
                        if self.led:
                            self.led.blink(on_time=0.2, off_time=0.8)
                        
                        if max_reconnect and attempts > max_reconnect:
                            logger.error("Max reconnect attempts reached; stopping.")
                            self.proc = None
                            if self.led:
                                self.led.off()
                        else:
                            logger.info(f"Reconnecting in {reconnect_wait}s... (attempt {attempts})")
                            time.sleep(reconnect_wait)
                            self.start()
                    else:
                        attempts = 0  # Reset counter on successful operation
                
                time.sleep(0.2)
                
        except KeyboardInterrupt:
            logger.info("Received interrupt signal, shutting down...")
        except Exception as e:
            logger.error(f"Unexpected error in main loop: {e}")
        finally:
            self.stop()
            if btn:
                btn.close()

def main():
    """Main entry point."""
    try:
        env = Env(CONFIG_PATH)
        logger.info("Configuration loaded successfully")
        
        # Validate configuration
        env.validate_required()
        logger.info("Configuration validation passed")
        
        ctl = StreamController(env)
        
        # Set up signal handlers
        def _sigterm(signum, frame):
            logger.info("Received termination signal")
            ctl.stop()
            sys.exit(0)
        
        signal.signal(signal.SIGTERM, _sigterm)
        signal.signal(signal.SIGINT, _sigterm)
        
        ctl.run()
        
    except FileNotFoundError as e:
        logger.error(f"Configuration file not found: {e}")
        logger.error("Please run the installer or create /etc/rtmp-streamer.env")
        sys.exit(1)
    except ValueError as e:
        logger.error(f"Configuration error: {e}")
        logger.error("Please check your /etc/rtmp-streamer.env file")
        sys.exit(1)
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
