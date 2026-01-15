#!/usr/bin/env bash
# WaybarPlayerctl.sh - Single instance playerctl wrapper with proper cleanup

set -euo pipefail

# Single-instance guard
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
pidfile="$RUNTIME_DIR/waybar-playerctl.pid"

# Kill previous instance if exists
if [[ -f "$pidfile" ]]; then
  oldpid="$(cat "$pidfile" 2>/dev/null || true)"
  if [[ -n "$oldpid" ]] && kill -0 "$oldpid" 2>/dev/null; then
    kill "$oldpid" 2>/dev/null || true
    sleep 0.1
  fi
fi

# Save our PID
echo $$ > "$pidfile"

# Cleanup on exit
cleanup() {
  rm -f "$pidfile"
  # Kill any child processes
  pkill -P $$ 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# Run playerctl
exec playerctl -a metadata --format '{"text": "{{artist}}  {{markup_escape(title)}}", "tooltip": "{{playerName}} : {{markup_escape(title)}}", "alt": "{{status}}", "class": "{{status}}"}' -F
