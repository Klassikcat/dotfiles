#!/bin/bash

# Hyprland Theme Daemon - Time-based theme switcher
# Switches between light (6 AM - 6 PM) and dark (6 PM - 6 AM)

DAY_START=6
NIGHT_START=18

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a /tmp/hyprland-theme-daemon.log
}

apply_theme() {
    local mode=$1
    local theme_file="$HOME/.cache/.theme_mode"
    
    # Read current theme
    current_theme=$(cat "$theme_file" 2>/dev/null || echo "Dark")
    
    # Check if we need to switch
    if [ "$mode" = "dark" ] && [ "$current_theme" = "Light" ]; then
        log "Switching to dark theme..."
        $HOME/.config/hypr/scripts/DarkLight.sh
    elif [ "$mode" = "light" ] && [ "$current_theme" = "Dark" ]; then
        log "Switching to light theme..."
        $HOME/.config/hypr/scripts/DarkLight.sh
    else
        log "Already in $mode theme"
    fi
}

get_theme_by_time() {
    local hour=$(date +%H | sed 's/^0//')
    
    # Handle time wrapping around midnight
    if [ "$DAY_START" -lt "$NIGHT_START" ]; then
        # Normal case: e.g., 6 AM (DAY_START) to 6 PM (NIGHT_START)
        if [ "$hour" -ge "$DAY_START" ] && [ "$hour" -lt "$NIGHT_START" ]; then
            echo "light"
        else
            echo "dark"
        fi
    else
        # Inverted case: e.g., 6 PM (DAY_START) to 6 AM (NIGHT_START)
        if [ "$hour" -ge "$DAY_START" ] || [ "$hour" -lt "$NIGHT_START" ]; then
            echo "light"
        else
            echo "dark"
        fi
    fi
}

log "Hyprland theme daemon started"
apply_theme "$(get_theme_by_time)"

# Check every minute
while true; do
    sleep 60
    current_theme=$(get_theme_by_time)
    previous_theme=$(cat /tmp/hyprland-current-theme 2>/dev/null || echo "")
    
    if [ "$current_theme" != "$previous_theme" ]; then
        apply_theme "$current_theme"
        echo "$current_theme" > /tmp/hyprland-current-theme
    fi
done
