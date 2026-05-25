#!/usr/bin/env bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  #
# Overview toggle wrapper - tries Quickshell first, falls back to AGS

set -euo pipefail

# 1) Try Quickshell via IPC (works if QS is running and listening)
if pgrep -x quickshell >/dev/null 2>&1; then
  if qs ipc -c overview call overview toggle >/dev/null 2>&1; then
    exit 0
  fi
fi

# If QS isn't running, but the CLI exists, try starting it and retry once
if command -v qs >/dev/null 2>&1; then
  qs -c overview >/dev/null 2>&1 &
  sleep 0.6
  if qs ipc -c overview call overview toggle >/dev/null 2>&1; then
    exit 0
  fi
fi

is_aylur_ags() {
  command -v ags >/dev/null 2>&1 || return 1
  ags --version 2>&1 | head -n1 | grep -qi 'Adventure Game Studio' && return 1
  [ -d "$HOME/.config/ags" ] || return 1
  return 0
}

# 2) Fall back to AGS template
if is_aylur_ags; then
  pkill rofi || true
  if ags -t 'overview' >/dev/null 2>&1; then
    exit 0
  fi
  # If it failed, try starting AGS daemon then call the template
  ags >/dev/null 2>&1 &
  sleep 0.6
  if ags -t 'overview' >/dev/null 2>&1; then
    exit 0
  fi
fi

# If we get here, neither worked
notify-send "Overview" "Neither Quickshell nor AGS is available" -u low 2>/dev/null || true
exit 1
