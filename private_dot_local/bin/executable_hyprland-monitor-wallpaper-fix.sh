#!/usr/bin/env bash
# Re-apply swww wallpaper after Hyprland monitor topology changes.
# This fixes stretched/cached wallpaper on rotated monitors after hot-plug/profile changes.

set -u

SOCKET_DIR="$XDG_RUNTIME_DIR/hypr/${HYPRLAND_INSTANCE_SIGNATURE:-}"
SOCKET="$SOCKET_DIR/.socket2.sock"
WALLPAPER_CURRENT="$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"
LOG="$HOME/.local/share/hyprland-monitor-wallpaper-fix.log"
LOCK="/tmp/.hyprland_monitor_wallpaper_fix.lock"

log() {
  mkdir -p "$(dirname "$LOG")"
  printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$LOG"
}

current_wallpaper() {
  if [[ -f "$WALLPAPER_CURRENT" ]]; then
    printf '%s\n' "$WALLPAPER_CURRENT"
    return 0
  fi

  # Fallback: first image path reported by swww.
  swww query 2>/dev/null | awk -F'image: ' '/currently displaying: image:/ {print $2; exit}'
}

reload_wallpaper() {
  (
    flock -n 9 || exit 0

    # Give hyprdynamicmonitors/Hyprland time to finish applying transform/scale.
    sleep 2.5

    # If live wallpaper is active, do not fight mpvpaper.
    if pgrep -x mpvpaper >/dev/null 2>&1; then
      log "skip: mpvpaper is running"
      exit 0
    fi

    if ! swww query >/dev/null 2>&1; then
      swww-daemon --format xrgb >/dev/null 2>&1 &
      sleep 0.5
    fi

    wallpaper="$(current_wallpaper)"
    if [[ -z "${wallpaper:-}" || ! -f "$wallpaper" ]]; then
      log "skip: wallpaper not found: ${wallpaper:-<empty>}"
      exit 0
    fi

    swww img --resize crop "$wallpaper" --transition-type none >/dev/null 2>&1 \
      && log "reloaded: $wallpaper" \
      || log "failed: swww img $wallpaper"
  ) 9>"$LOCK" &
}

if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" || ! -S "$SOCKET" ]]; then
  log "error: Hyprland event socket not found: $SOCKET"
  exit 1
fi

# Also normalize once when the watcher starts.
reload_wallpaper

socat -U - UNIX-CONNECT:"$SOCKET" | while IFS= read -r event; do
  case "$event" in
    monitoradded*|monitorremoved*|configreloaded*)
      reload_wallpaper
      ;;
  esac
done
