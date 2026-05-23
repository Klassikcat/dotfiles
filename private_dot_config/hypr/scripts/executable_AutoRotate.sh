#!/usr/bin/env bash
# Rotate the internal Hyprland display and matching touch devices from iio-sensor-proxy events.

set -u

monitor_name="${HYPR_AUTO_ROTATE_MONITOR:-eDP-1}"
log_file="${XDG_STATE_HOME:-$HOME/.local/state}/hypr-auto-rotate.log"
lock_file="${XDG_RUNTIME_DIR:-/tmp}/hypr-auto-rotate.lock"
last_transform=""

mkdir -p "$(dirname "$log_file")"

log() {
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$log_file"
}

orientation_to_transform() {
  case "$1" in
    normal) printf '0\n' ;;
    bottom-up) printf '2\n' ;;
    left-up) printf '1\n' ;;
    right-up) printf '3\n' ;;
    *) return 1 ;;
  esac
}

monitor_spec() {
  hyprctl monitors -j | jq -er --arg name "$monitor_name" '
    .[]
    | select(.name == $name)
    | "\(.name),\(.width)x\(.height)@\(.refreshRate),\(.x)x\(.y),\(.scale)"
  '
}

bind_input_to_monitor() {
  hyprctl keyword input:touchdevice:output "$monitor_name" >/dev/null 2>&1 || true
  hyprctl keyword input:tablet:output "$monitor_name" >/dev/null 2>&1 || true
}

apply_input_transform() {
  local transform="$1"

  hyprctl keyword input:touchdevice:transform "$transform" >/dev/null 2>&1 || true
  hyprctl keyword input:tablet:transform "$transform" >/dev/null 2>&1 || true
}

apply_transform() {
  local transform="$1"
  local spec

  if [ "$transform" = "$last_transform" ]; then
    return 0
  fi

  spec="$(monitor_spec 2>/dev/null)" || {
    log "monitor not found: $monitor_name"
    return 1
  }

  hyprctl keyword monitor "$spec,transform,$transform" >/dev/null || {
    log "failed monitor transform=$transform spec=$spec"
    return 1
  }

  bind_input_to_monitor
  apply_input_transform "$transform"

  last_transform="$transform"
  log "applied orientation transform=$transform monitor=$monitor_name"
}

apply_orientation() {
  local orientation="$1"
  local transform

  transform="$(orientation_to_transform "$orientation")" || return 0
  apply_transform "$transform"
}

case "${1:-}" in
  --apply-orientation)
    [ -n "${2:-}" ] || { printf 'usage: %s --apply-orientation normal|bottom-up|left-up|right-up\n' "$0" >&2; exit 2; }
    apply_orientation "$2"
    exit $?
    ;;
  --apply-transform)
    [ -n "${2:-}" ] || { printf 'usage: %s --apply-transform 0|1|2|3\n' "$0" >&2; exit 2; }
    apply_transform "$2"
    exit $?
    ;;
  --help|-h)
    printf 'Usage: %s [--apply-orientation ORIENTATION|--apply-transform N]\n' "$0"
    printf 'Without arguments, follows monitor-sensor and rotates %s plus touch/tablet inputs.\n' "$monitor_name"
    exit 0
    ;;
esac

exec 9>"$lock_file"
if ! flock -n 9; then
  exit 0
fi

command -v monitor-sensor >/dev/null || { log 'monitor-sensor not found'; exit 1; }
command -v hyprctl >/dev/null || { log 'hyprctl not found'; exit 1; }
command -v jq >/dev/null || { log 'jq not found'; exit 1; }

bind_input_to_monitor
log "started monitor=$monitor_name"

while IFS= read -r line; do
  case "$line" in
    *'Accelerometer orientation changed: '* )
      apply_orientation "${line##*: }"
      ;;
    *'orientation: normal'* )
      apply_orientation normal
      ;;
    *'orientation: bottom-up'* )
      apply_orientation bottom-up
      ;;
    *'orientation: left-up'* )
      apply_orientation left-up
      ;;
    *'orientation: right-up'* )
      apply_orientation right-up
      ;;
  esac
done < <(monitor-sensor 2>&1)

log 'monitor-sensor exited'
