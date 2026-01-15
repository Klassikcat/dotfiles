#!/bin/bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# Scripts for refreshing ags, waybar, rofi, swaync, wallust

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

# Kill already running processes
# Note: swaync is managed by systemd, don't kill it here
_ps=(waybar rofi ags playerctl)
for _prs in "${_ps[@]}"; do
    if pidof "${_prs}" >/dev/null; then
        pkill "${_prs}"
    fi
done

# Kill only waybar-cava instances (not other cava processes)
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
for pid in $(pgrep -f "cava -p $RUNTIME_DIR/waybar-cava"); do
    kill "$pid" 2>/dev/null || true
done

# added since wallust sometimes not applying
killall -SIGUSR2 waybar 

# quit ags & relaunch ags
ags -q && ags &

# quit quickshell & relaunch quickshell
#pkill qs && qs &

# some process to kill
for pid in $(pidof waybar rofi swaync ags swaybg); do
    kill -SIGUSR1 "$pid"
done

#Restart waybar
sleep 1
$SCRIPTSDIR/WaybarStart.sh &

#reload swaync
sleep 0.5
swaync-client --reload-config &

# Relaunching rainbow borders if the script exists
sleep 1
if file_exists "${UserScripts}/RainbowBorders.sh"; then
    ${UserScripts}/RainbowBorders.sh &
fi

exit 0
