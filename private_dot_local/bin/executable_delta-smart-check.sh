#!/bin/bash

# Smart Delta Theme Checker
# Updates delta theme based on system color scheme (GNOME)

CACHE_FILE="$HOME/.local/share/delta-theme-cache"
CURRENT_TIME=$(date +%s)

# Get system color scheme (GNOME)
SYSTEM_COLOR_SCHEME=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null)

# Determine what theme should be active based on system setting
if [ "$SYSTEM_COLOR_SCHEME" = "'prefer-light'" ] || [ "$SYSTEM_COLOR_SCHEME" = "'default'" ]; then
    SHOULD_BE_LIGHT=true
else
    # 'prefer-dark' or any other value defaults to dark theme
    SHOULD_BE_LIGHT=false
fi

# Get current theme setting
CURRENT_LIGHT=$(git config --global --get delta.light)

# Check if we need to update
NEED_UPDATE=false

# If cache file doesn't exist or is older than 5 minutes, check
# (Reduced from 30 minutes for faster system theme response)
if [ ! -f "$CACHE_FILE" ]; then
    NEED_UPDATE=true
else
    LAST_CHECK=$(cat "$CACHE_FILE" 2>/dev/null || echo "0")
    TIME_DIFF=$((CURRENT_TIME - LAST_CHECK))
    if [ $TIME_DIFF -gt 300 ]; then  # 5 minutes = 300 seconds
        NEED_UPDATE=true
    fi
fi

# Also update if the theme is wrong (most important for system theme sync)
if [ "$CURRENT_LIGHT" != "$SHOULD_BE_LIGHT" ]; then
    NEED_UPDATE=true
fi

# Update theme if needed
if [ "$NEED_UPDATE" = "true" ]; then
    BAT_CONFIG="$HOME/.config/bat/config"
    
    if [ "$SHOULD_BE_LIGHT" = "true" ]; then
        git config --global delta.light true
        git config --global delta.theme "Catppuccin Latte"
        
        # Update bat config file
        mkdir -p "$(dirname "$BAT_CONFIG")"
        if [ -f "$BAT_CONFIG" ]; then
            sed -i '/^--theme=/d' "$BAT_CONFIG"
        fi
        echo '--theme="Catppuccin Latte"' >> "$BAT_CONFIG"
        
        echo "$(date +"%H:%M"): Themes set to light - delta: Catppuccin Latte, bat: Catppuccin Latte (system: $SYSTEM_COLOR_SCHEME)" >> ~/.local/share/delta-theme.log
    else
        git config --global delta.light false
        git config --global delta.theme "Catppuccin Mocha"
        
        # Update bat config file
        mkdir -p "$(dirname "$BAT_CONFIG")"
        if [ -f "$BAT_CONFIG" ]; then
            sed -i '/^--theme=/d' "$BAT_CONFIG"
        fi
        echo '--theme="Catppuccin Mocha"' >> "$BAT_CONFIG"
        
        echo "$(date +"%H:%M"): Themes set to dark - delta: Catppuccin Mocha, bat: Catppuccin Mocha (system: $SYSTEM_COLOR_SCHEME)" >> ~/.local/share/delta-theme.log
    fi
    
    # Update cache
    echo "$CURRENT_TIME" > "$CACHE_FILE"
fi
