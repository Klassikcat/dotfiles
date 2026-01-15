#!/bin/bash

# Delta Manual Theme Toggle
# Manually switches between light and dark themes

# Get current delta light setting
current_setting=$(git config --global --get delta.light)

if [ "$current_setting" = "true" ]; then
    # Currently light, switch to dark
    git config --global delta.light false
    echo "Switched to delta dark theme"
else
    # Currently dark or not set, switch to light
    git config --global delta.light true
    echo "Switched to delta light theme"
fi

# Log the manual change
echo "$(date): Delta theme manually toggled" >> ~/.local/share/delta-theme.log