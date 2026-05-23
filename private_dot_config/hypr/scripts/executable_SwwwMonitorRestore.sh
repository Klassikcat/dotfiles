#!/bin/bash
# Restore swww wallpapers when Hyprland monitor hotplug events fire.

wallpaper_current="$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"
restore_delay=0.5

monitor_names() {
  hyprctl monitors -j 2>/dev/null | jq -r '.[].name' 2>/dev/null
}

socket_path() {
  [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || return 1
  printf '%s/hypr/%s/.socket2.sock\n' "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" "$HYPRLAND_INSTANCE_SIGNATURE"
}

wait_for_socket() {
  local socket

  for _ in {1..50}; do
    socket="$(socket_path)" || return 1
    if [ -S "$socket" ]; then
      printf '%s\n' "$socket"
      return 0
    fi
    sleep 0.1
  done

  return 1
}

listen_events() {
  local socket="$1"

  if command -v socat >/dev/null 2>&1; then
    socat -u UNIX-CONNECT:"$socket" -
  elif command -v nc >/dev/null 2>&1; then
    nc -U -d "$socket"
  else
    return 1
  fi
}

ensure_swww() {
  if swww query >/dev/null 2>&1; then
    return 0
  fi

  swww-daemon --format xrgb >/dev/null 2>&1 &

  for _ in {1..20}; do
    sleep 0.1
    swww query >/dev/null 2>&1 && return 0
  done

  return 1
}

restore_wallpaper() {
  # mpvpaper owns live wallpapers; do not replace it with a static swww image.
  if pgrep -x mpvpaper >/dev/null 2>&1; then
    return 0
  fi

  [ -f "$wallpaper_current" ] || return 0
  ensure_swww || return 0

  monitor_names | while IFS= read -r monitor; do
    [ -n "$monitor" ] || continue
    swww img -o "$monitor" "$wallpaper_current" --transition-type none >/dev/null 2>&1
  done
}

schedule_restore() {
  local run_lock="${XDG_RUNTIME_DIR:-/tmp}/swww-monitor-restore-run.lock"

  (
    if ! mkdir "$run_lock" 2>/dev/null; then
      exit 0
    fi
    trap 'rmdir "$run_lock"' EXIT

    sleep "$restore_delay"
    restore_wallpaper
  ) &
}

if [ "$1" = "--once" ]; then
  restore_wallpaper
  exit 0
fi

lock_dir="${XDG_RUNTIME_DIR:-/tmp}/swww-monitor-restore.lock"
if ! mkdir "$lock_dir" 2>/dev/null; then
  old_pid="$(cat "$lock_dir/pid" 2>/dev/null)"
  if [ -n "$old_pid" ] && kill -0 "$old_pid" 2>/dev/null; then
    exit 0
  fi

  rm -f "$lock_dir/pid"
  rmdir "$lock_dir" 2>/dev/null || exit 0
  mkdir "$lock_dir" 2>/dev/null || exit 0
fi
printf '%s\n' "$$" > "$lock_dir/pid"
trap 'rm -f "$lock_dir/pid"; rmdir "$lock_dir"' EXIT

# Seed current outputs at startup; after that, react only to Hyprland events.
restore_wallpaper

while true; do
  socket="$(wait_for_socket)" || exit 0

  while IFS= read -r event; do
    case "$event" in
      monitoradded*|monitorremoved*)
        schedule_restore
        ;;
    esac
  done < <(listen_events "$socket")

  sleep 1
done
