#!/bin/bash

# Delta Auto Theme Switcher
# Switches between light (06:30-19:30) and dark (19:30-06:30) themes

# Get current time in HH:MM format (24-hour)
current_time=$(date +"%H:%M")
current_hour=$(date +"%H")
current_minute=$(date +"%M")

# Convert time to minutes since midnight for easier comparison
current_minutes=$((10#$current_hour * 60 + 10#$current_minute))

# Define time ranges in minutes since midnight
# 06:30 = 6*60 + 30 = 390 minutes
# 19:30 = 19*60 + 30 = 1170 minutes
light_start=390    # 06:30
light_end=1170     # 19:30

# Determine which theme to use
if [ $current_minutes -ge $light_start ] && [ $current_minutes -lt $light_end ]; then
    # Light theme (06:30 - 19:30)
    theme="light"
    git config --global delta.light true
    echo "[$current_time] Switched to delta light theme"
else
    # Dark theme (19:30 - 06:30)
    theme="dark"
    git config --global delta.light false
    echo "[$current_time] Switched to delta dark theme"
fi

# Optional: Log the change
echo "$(date): Delta theme switched to $theme" >> ~/.local/share/delta-theme.log