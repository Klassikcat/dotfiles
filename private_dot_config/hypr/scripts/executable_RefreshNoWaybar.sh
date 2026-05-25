#!/bin/bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##

# Modified version of Refresh.sh but waybar wont refresh
# Used by automatic wallpaper change
# Modified inorder to refresh rofi background, Wallust, SwayNC only

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
_ps=(rofi)
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

# Wallust refresh (synchronous to ensure colors are ready)
${SCRIPTSDIR}/WallustSwww.sh
sleep 0.2

# reload swaync
swaync-client --reload-config

# Relaunching rainbow borders if the script exists
sleep 1
if file_exists "${UserScripts}/RainbowBorders.sh"; then
    ${UserScripts}/RainbowBorders.sh &
fi


exit 0