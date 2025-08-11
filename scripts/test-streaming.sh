#!/bin/bash

# PI-DATV-WWATS Streaming Test Script
# Tests complete streaming functionality with improved FFmpeg command

echo "=== PI-DATV-WWATS Streaming Test ==="
echo "Testing complete system functionality..."
echo

# Function to check if service is running
check_service() {
    local service=$1
    local status=$(systemctl is-active $service 2>/dev/null)
    if [ "$status" = "active" ]; then
        echo "✓ $service is running"
        return 0
    else
        echo "✗ $service is not running (status: $status)"
        return 1
    fi
}

# Function to test camera access
test_camera() {
    echo "Testing camera access..."
    if [ -c /dev/video0 ]; then
        echo "✓ Camera device /dev/video0 exists"
        # Quick test to see if camera is accessible
        if v4l2-ctl --device=/dev/video0 --list-formats-ext >/dev/null 2>&1; then
            echo "✓ Camera is accessible"
            return 0
        else
            echo "✗ Camera access denied or busy"
            return 1
        fi
    else
        echo "✗ Camera device /dev/video0 not found"
        return 1
    fi
}

# Function to test UDP stream
test_udp_stream() {
    echo "Testing UDP stream (listening for 5 seconds)..."
    timeout 5 nc -u -l 5005 >/dev/null 2>&1
    if [ $? -eq 124 ]; then
        echo "✓ UDP port 5005 is accessible"
        return 0
    else
        echo "? UDP stream test inconclusive"
        return 1
    fi
}

# Function to simulate START command
test_start_command() {
    echo "Simulating START streaming command..."
    echo "start" > /home/datv/rtmp_command
    sleep 2
    
    # Check if status file is created
    if [ -f /home/datv/rtmp_status ]; then
        local status=$(cat /home/datv/rtmp_status 2>/dev/null)
        echo "Status file content: $status"
        if [[ "$status" == *"starting"* ]] || [[ "$status" == *"running"* ]]; then
            echo "✓ START command processed successfully"
            return 0
        else
            echo "✗ START command failed: $status"
            return 1
        fi
    else
        echo "✗ Status file not created"
        return 1
    fi
}

# Function to test STOP command
test_stop_command() {
    echo "Simulating STOP streaming command..."
    echo "stop" > /home/datv/rtmp_command
    sleep 2
    
    # Check status
    if [ -f /home/datv/rtmp_status ]; then
        local status=$(cat /home/datv/rtmp_status 2>/dev/null)
        echo "Status file content: $status"
        if [[ "$status" == *"stopped"* ]] || [[ "$status" == *"idle"* ]]; then
            echo "✓ STOP command processed successfully"
            return 0
        else
            echo "? STOP command result: $status"
            return 1
        fi
    else
        echo "? Status file not found after STOP"
        return 1
    fi
}

# Function to check FFmpeg process
check_ffmpeg() {
    local ffmpeg_count=$(pgrep -c ffmpeg)
    if [ $ffmpeg_count -gt 0 ]; then
        echo "✓ FFmpeg process running ($ffmpeg_count instances)"
        return 0
    else
        echo "- No FFmpeg process running"
        return 1
    fi
}

# Function to display system info
show_system_info() {
    echo "=== System Information ==="
    echo "User: $(whoami)"
    echo "Groups: $(groups)"
    echo "Python version: $(python3 --version 2>/dev/null || echo 'Not found')"
    echo "FFmpeg version: $(ffmpeg -version 2>/dev/null | head -1 || echo 'Not found')"
    echo "V4L2 utils: $(v4l2-ctl --version 2>/dev/null | head -1 || echo 'Not found')"
    echo
}

# Main test sequence
main() {
    show_system_info
    
    echo "=== Service Status Check ==="
    check_service "rtmp-ui.service"
    check_service "rtmp-streamer.service" 
    check_service "rtmp-preview.service"
    echo
    
    echo "=== Hardware Tests ==="
    test_camera
    test_udp_stream
    echo
    
    echo "=== Command Communication Tests ==="
    test_start_command
    sleep 3
    check_ffmpeg
    echo
    
    test_stop_command
    sleep 2
    check_ffmpeg
    echo
    
    echo "=== File System Check ==="
    echo "Command file: $(ls -la /home/datv/rtmp_command 2>/dev/null || echo 'Not found')"
    echo "Status file: $(ls -la /home/datv/rtmp_status 2>/dev/null || echo 'Not found')"
    echo
    
    echo "=== Log Files Check ==="
    echo "Recent rtmp-streamer logs:"
    journalctl -u rtmp-streamer.service --since "5 minutes ago" --no-pager -n 5 2>/dev/null || echo "No recent logs"
    echo
    
    echo "=== Test Complete ==="
    echo "Check the output above for any issues marked with ✗"
    echo "To view live logs: journalctl -u rtmp-streamer.service -f"
    echo "Web UI: http://localhost:8080"
}

# Check if running as correct user
if [ "$(whoami)" != "datv" ]; then
    echo "Warning: This script should be run as user 'datv'"
    echo "Current user: $(whoami)"
    echo
fi

main "$@"
