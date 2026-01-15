#!/bin/bash

# Wait for Hyprland IPC to be ready, then run theme update script

max_attempts=10
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if hyprctl dispatch dpms on 2>/dev/null; then
        # Hyprland is ready, run theme and brightness update scripts
        $HOME/.local/bin/hyprland-theme-init.sh
        $HOME/.local/bin/brightness-init.sh
        exit 0
    fi
    attempt=$((attempt + 1))
    sleep 0.5
done

systemctl --user restart hyprland-theme@sunrise-light.service
systemctl --user restart hyprland-theme@sunset-dark.service

# If we get here, Hyprland didn't respond in time
echo "Warning: Hyprland IPC didn't respond after ${max_attempts} attempts" >&2
exit 1
