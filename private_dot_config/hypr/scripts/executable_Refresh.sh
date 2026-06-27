#!/bin/bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# Scripts for refreshing ags, rofi, swaync, wallust

SCRIPTSDIR=$HOME/.config/hypr/scripts
UserScripts=$HOME/.config/hypr/UserScripts

# Define file_exists function
file_exists() {
    if [ -e "$1" ]; then
        return 0  # File exists
    else
        return 1  # File does not exist
    fi
}

is_aylur_ags() {
    command -v ags >/dev/null 2>&1 || return 1
    ags --version 2>&1 | head -n1 | grep -qi 'Adventure Game Studio' && return 1
    [ -d "$HOME/.config/ags" ] || return 1
    return 0
}

# Kill already running processes
# Note: swaync is managed by systemd, don't kill it here
_ps=(rofi playerctl)
if is_aylur_ags; then
    _ps+=(ags)
fi
for _prs in "${_ps[@]}"; do
    if pidof "${_prs}" >/dev/null; then
        pkill "${_prs}"
    fi
done

# quit ags & relaunch ags
if is_aylur_ags; then
    ags -q && ags &
fi

# quit quickshell & relaunch quickshell
#pkill qs && qs &

# some process to signal
# Note: swaync is managed by systemd and should be reloaded, not signalled.
_signal_processes=(rofi swaybg)
if is_aylur_ags; then
    _signal_processes+=(ags)
fi
for pid in $(pidof "${_signal_processes[@]}"); do
    kill -SIGUSR1 "$pid"
done

# reload swaync without killing/restarting it
sleep 0.5
swaync-client --reload-css >/dev/null 2>&1 || true
swaync-client --reload-config >/dev/null 2>&1 || true

# Relaunching rainbow borders if the script exists
sleep 1
if file_exists "${UserScripts}/RainbowBorders.sh"; then
    ${UserScripts}/RainbowBorders.sh &
fi

exit 0
