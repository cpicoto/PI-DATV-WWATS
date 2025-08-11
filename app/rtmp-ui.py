#!/usr/bin/env python3
from flask import Flask, redirect, render_template_string
import subprocess, os

def send_command(cmd):
    """Send a command to the streamer process."""
    try:
        with open(COMMAND_FILE, 'w') as f:
            f.write(cmd)
        return True
    except Exception as e:
        print(f"Error sending command: {e}")
        return False

TEMPLATE = """
<!doctype html>
<title>PI-DATV-WWATS</title>
<meta name=viewport content="width=device-width, initial-scale=1">
<style>
  body { font-family: system-ui, sans-serif; background:#0b0b0b; color:#eaeaea; text-align:center; }
  .wrap { max-width: 900px; margin: 6vh auto; }
  .btn { font-size: 3rem; padding: 1rem 2rem; margin: 1rem; border-radius: 1rem; border:0; cursor:pointer; display:inline-block; text-decoration:none; color:#fff; }
  .go   { background:#1db954; }
  .stop { background:#e53935; }
  .row { margin-top: 2rem; }
  .stat { margin-top: 1.4rem; opacity:.9; white-space: pre-line; font-family: ui-monospace, monospace; font-size:1.1rem; text-align:left; display:inline-block; }
</style>
<div class=wrap>
  <h1>PI-DATV-WWATS</h1>
  <div class=row>
    <a class="btn go"  href="/start">Start</a>
    <a class="btn stop" href="/stop">Stop</a>
  </div>
  <div class=stat>{{status}}</div>
</div>
"""

app = Flask(__name__)

SERVICE = 'rtmp-streamer.service'
STATUS_FILE = '/run/rtmp-status.txt'
COMMAND_FILE = '/home/datv/rtmp-command.txt'

def svc(cmd):
    return subprocess.run(['systemctl', cmd, SERVICE], capture_output=True, text=True)

def send_command(cmd):
    """Send a command to the streamer process."""
    try:
        # Create command file with proper permissions for cross-user access
        with open(COMMAND_FILE, 'w') as f:
            f.write(cmd)
        
        # Make the file readable/writable by both users
        import stat
        import os
        os.chmod(COMMAND_FILE, stat.S_IRUSR | stat.S_IWUSR | stat.S_IRGRP | stat.S_IWGRP | stat.S_IROTH | stat.S_IWOTH)
        
        return True
    except Exception as e:
        print(f"Error sending command: {e}")
        return False

@app.route('/')
def index():
    s = subprocess.run(['systemctl','is-active',SERVICE], capture_output=True, text=True).stdout.strip()
    overlay = ''
    if os.path.exists(STATUS_FILE):
        try:
            overlay = open(STATUS_FILE).read()
        except Exception:
            pass
    return render_template_string(TEMPLATE, status=f"Service: {s}\n" + overlay)

@app.route('/start')
def start():
    send_command('start')
    return redirect('/')

@app.route('/stop')
def stop():
    send_command('stop')
    return redirect('/')

if __name__ == '__main__':
    # Bind to all interfaces to support LAN access; kiosk uses http://localhost:8080
    app.run(host='0.0.0.0', port=8080)
