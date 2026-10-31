#!/bin/bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# searchable enabled keybinds using rofi

# kill yad to not interfere with this binds
pkill yad || true

# check if rofi is already running
if pidof rofi > /dev/null; then
  pkill rofi
fi

# keybinds live in hyprland.lua since Hyprland 0.57 (Lua config)
hypr_lua="$HOME/.config/hypr/hyprland.lua"
rofi_theme="$HOME/.config/rofi/config-keybinds.rasi"
msg='☣️ NOTE ☣️: Clicking with Mouse or Pressing ENTER will have NO function'

keybinds=$(grep -E '^\s*(bind|exec)\(' "$hypr_lua")

# check for any keybinds to display
if [[ -z "$keybinds" ]]; then
    echo "no keybinds found."
    exit 1
fi

# replace $mainmod with super in the displayed keybinds for rofi
display_keybinds=$(echo "$keybinds" | sed 's/M \.\. "/"SUPER + /; s/^\s*//')

# use rofi to display the keybinds with the modified content
echo "$display_keybinds" | rofi -dmenu -i -config "$rofi_theme" -mesg "$msg"