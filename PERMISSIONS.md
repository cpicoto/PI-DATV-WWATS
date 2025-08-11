# PI-DATV-WWATS System Architecture & Permissions

## ✅ SIMPLIFIED: Single-User Architecture

This document explains the **simplified single-user model** for PI-DATV-WWATS.

## User Model

### Single User: `datv`
- **All services run as `datv`** - Eliminates permission conflicts
- **All files owned by `datv`** - No cross-user access issues  
- **User logs in as `datv`** - Consistent throughout system

### Why Single-User?
1. **Simplicity**: No permission conflicts between users
2. **Reliability**: Services can access all files they need
3. **Maintainability**: One user to manage, not two

## Service Configuration

### All Services Run as datv - CRITICAL GROUP SETTINGS

⚠️ **REGRESSION ALERT**: This has been corrected TWICE already!

```ini
# rtmp-streamer.service - CORRECT CONFIGURATION
User=datv
Group=datv                    # ← MUST be datv, NOT video!
SupplementaryGroups=video,audio,plugdev,render,input,gpio

# rtmp-ui.service  
User=datv
Group=datv

# rtmp-preview.service
User=datv
Group=datv                    # ← MUST be datv, NOT video!
```

### ❌ CRITICAL MISTAKE - DO NOT REPEAT:
```ini
# This causes status=216/GROUP error:
Group=video    # WRONG! Causes systemd GROUP error
```

### ✅ CORRECT PATTERN:
```ini
# Primary group MUST match the user:
User=datv
Group=datv     # Same as user - prevents GROUP errors
SupplementaryGroups=video,audio,plugdev,render,input,gpio  # Additional access
```

## Permission Model

### No Cross-User Issues
- Web UI runs as `datv` → creates files owned by `datv`
- Services run as `datv` → can read files owned by `datv`  
- **Result**: No permission errors!

### File Ownership
- `/opt/pi-datv-wwats/` - Owned by `datv:datv`
- `/tmp/rtmp-command.txt` - Created by `datv`, readable by `datv`
- `/run/rtmp-status.txt` - Created by `datv`, readable by `datv`

## Group Memberships

### datv user groups
```bash
# datv user needs these groups for hardware access when running manual commands
sudo usermod -a -G video,audio,plugdev,gpio datv
```

### pi user groups
```bash
# pi user gets groups from service SupplementaryGroups automatically
# video, audio, plugdev, render, input, gpio
```

## Common Mistakes to AVOID

### ❌ REGRESSION #1: Wrong primary Group setting  
```ini
# This causes status=216/GROUP systemd error - FIXED TWICE!
User=datv
Group=video    # WRONG! Must be Group=datv
```

### ❌ REGRESSION #2: Use whoami in sudo scripts
```bash
# This returns 'root' when script run with sudo
REAL_USER=$(whoami)  # WRONG!

# Use this instead:
REAL_USER=${SUDO_USER:-$(whoami)}  # CORRECT!
```

### ❌ DON'T: Change service users to datv
```ini
# This BREAKS the system - causes status=216/GROUP errors
User=datv  # WRONG!
```

### ❌ DON'T: Change /opt/pi-datv-wwats ownership
```bash
# This breaks service execution
sudo chown -R datv:datv /opt/pi-datv-wwats/  # WRONG!
```

### ❌ DON'T: Remove cross-user file permissions
```python
# This breaks web UI -> service communication
with open(file, 'w') as f:
    f.write(data)
# Missing: os.chmod(file, 0o666)  # REQUIRED!
```

## Troubleshooting

### Service Won't Start (status=216/GROUP) - REPEATED ISSUE!
- **Cause**: Wrong Group= setting in service file (FIXED TWICE ALREADY!)
- **Symptom**: `Group=video` instead of `Group=datv`
- **Fix**: Ensure `Group=datv` matches `User=datv` in ALL service files
- **Prevention**: Primary group MUST match the username!

### Permission Denied Errors
- **Cause**: Files owned by wrong user
- **Fix**: Run `sudo chown -R datv:datv /opt/pi-datv-wwats/`

### "Device or resource busy" Camera Errors
- **Cause**: Multiple services accessing camera directly
- **Fix**: Use UDP tee stream architecture (already implemented)

## Setup Commands

### Initial Setup
```bash
# Run the single-user fix script
sudo ./scripts/fix-single-user.sh
```

### Verify Setup
```bash
# Check service users
sudo systemctl show rtmp-streamer.service -p User
# Should show: User=datv

# Check file ownership  
ls -la /opt/pi-datv-wwats/
# Should show: datv datv

# Check user groups
groups datv
# Should include: video audio plugdev render input gpio
```

## Emergency Reset Procedure

If permissions get broken:

1. **Reset service users:**
   ```bash
   cd PI-DATV-WWATS
   git checkout HEAD -- services/
   sudo cp services/*.service /etc/systemd/system/
   sudo systemctl daemon-reload
   ```

2. **Fix directory ownership:**
   ```bash
   sudo chown -R pi:pi /opt/pi-datv-wwats/
   ```

3. **Add datv to required groups:**
   ```bash
   sudo usermod -a -G video,audio,plugdev,gpio datv
   ```

4. **Restart services:**
   ```bash
   sudo systemctl restart rtmp-streamer.service
   sudo systemctl restart rtmp-ui.service
   sudo systemctl restart rtmp-preview.service
   ```

## Design Principles

1. **Don't change what works** - The pi/datv split model is proven
2. **Use file permissions, not user changes** - For cross-user access
3. **Test before committing** - Always verify services start after changes
4. **Document assumptions** - Update this file when making changes

---

**Last Updated**: August 10, 2025  
**Critical**: This model prevents service failures and permission conflicts
