#!/usr/bin/env bash
set -u

SOURCE_NAME="internal_mic"
DEVICE="plughw:1,0"
DESC="Internal_Microphone"
LOG_TAG="load-internal-mic"

log() {
  systemd-cat -t "$LOG_TAG" echo "$*" 2>/dev/null || echo "$*"
}

# Wait until PipeWire-Pulse is reachable and the ALSA capture device has user ACLs.
ready=0
for _ in {1..30}; do
  if pactl info >/dev/null 2>&1 && [[ -r /dev/snd/pcmC1D0c && -w /dev/snd/pcmC1D0c ]]; then
    ready=1
    break
  fi
  sleep 1
done

if [[ "$ready" -ne 1 ]]; then
  log "not ready: pactl or /dev/snd/pcmC1D0c permission unavailable"
  exit 0
fi

sources="$(pactl list short sources 2>/dev/null || true)"

# If already loaded, do nothing.
if printf '%s\n' "$sources" | awk '{print $2}' | grep -Fxq "$SOURCE_NAME"; then
  log "$SOURCE_NAME already exists"
  exit 0
fi

# Count real non-monitor sources without failing when there are zero matches.
other_sources_count="$(printf '%s\n' "$sources" \
  | awk '{print $2}' \
  | grep -Ev '(^auto_null\.monitor$|\.monitor$)' \
  | grep -Fvx "$SOURCE_NAME" \
  | wc -l || true)"
other_sources_count="${other_sources_count//[[:space:]]/}"
[[ -n "$other_sources_count" ]] || other_sources_count=0

output="$(pactl load-module module-alsa-source \
  device="$DEVICE" \
  source_name="$SOURCE_NAME" \
  source_properties="device.description=$DESC" 2>&1)"
rc=$?

if [[ "$rc" -ne 0 ]]; then
  log "failed to load $SOURCE_NAME: $output"
  exit 0
fi

log "loaded $SOURCE_NAME module=$output"

# Make it default only when there was no other real source already connected.
# This avoids stealing default input from a headset mic that is present at login.
if [[ "$other_sources_count" -eq 0 ]]; then
  pactl set-default-source "$SOURCE_NAME" || true
  log "set default source to $SOURCE_NAME"
fi

exit 0
