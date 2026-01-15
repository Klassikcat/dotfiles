#!/usr/bin/env bash
# WaybarStart.sh - Start waybar with cleanup of old instances

# Kill old waybar and its child processes
pkill -9 cava 2>/dev/null || true
pkill -9 playerctl 2>/dev/null || true
pkill waybar 2>/dev/null || true

# Wait a moment for processes to die
sleep 0.5

# Clean up old pidfiles and temp configs
rm -f "${XDG_RUNTIME_DIR:-/tmp}/waybar-cava.pid" 2>/dev/null || true
rm -f "${XDG_RUNTIME_DIR:-/tmp}/waybar-playerctl.pid" 2>/dev/null || true
rm -f "${XDG_RUNTIME_DIR:-/tmp}"/waybar-cava.*.conf 2>/dev/null || true

# Start waybar - 모니터별 설정
waybar -c ~/.config/waybar/configs/"[TOP] Default - UltraFine" &
waybar -c ~/.config/waybar/configs/"[TOP] Default - HDR" &
wait
