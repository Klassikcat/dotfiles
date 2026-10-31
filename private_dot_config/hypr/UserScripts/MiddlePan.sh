#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in down|up) ;; *) exit 2 ;; esac
# Serialize release behind press so a quick click cannot leave a button held.
exec 9>"${XDG_RUNTIME_DIR:?}/hypr-middle-pan.lock"
flock 9

send_state() {
    local result
    result=$(hyprctl dispatch "hl.dsp.send_key_state({ mods = '', key = '$1', state = '$2' })")
    if [[ $result != ok ]]; then
        printf '%s\n' "$result" >&2
        return 1
    fi
}

release() {
    local failed=0
    send_state mouse:273 up || failed=1
    send_state SPACE up || failed=1
    return "$failed"
}

if [[ $1 == down ]]; then
    trap 'release' ERR
    send_state SPACE down
    send_state mouse:273 down
else
    release
fi
