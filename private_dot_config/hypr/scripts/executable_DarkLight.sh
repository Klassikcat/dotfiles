#!/bin/bash
## /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# For Dark and Light switching
# Note: Scripts are looking for keywords Light or Dark except for wallpapers as the are in a separate directories

# Paths
wallpaper_base_path="$HOME/Pictures/wallpapers/Dynamic-Wallpapers"
dark_wallpapers="$wallpaper_base_path/Dark"
light_wallpapers="$wallpaper_base_path/Light"
hypr_config_path="$HOME/.config/hypr"
swaync_style="$HOME/.config/swaync/style.css"
ags_style="$HOME/.config/ags/user/style.css"
SCRIPTSDIR="$HOME/.config/hypr/scripts"
notif="$HOME/.config/swaync/images/bell.png"
wallust_rofi="$HOME/.config/wallust/templates/colors-rofi.rasi"

kitty_conf="$HOME/.config/kitty/kitty.conf"

wallust_config="$HOME/.config/wallust/wallust.toml"
pallete_dark="dark16"
pallete_light="light16"

# intial kill process
for pid in waybar rofi swaync ags swaybg; do
    killall -SIGUSR1 "$pid"
done


# Set swww options (will only start daemon if needed for static wallpapers)
swww="swww img"
effect="--transition-bezier .43,1.19,1,.4 --transition-fps 60 --transition-type grow --transition-pos 0.925,0.977 --transition-duration 2"

# Check if a theme was specified as argument
if [ "$1" = "light" ]; then
    next_mode="Light"
    wallpaper_path="$light_wallpapers"
elif [ "$1" = "dark" ]; then
    next_mode="Dark"
    wallpaper_path="$dark_wallpapers"
else
    # Determine current theme mode if no argument provided
    current_theme=$(cat "$HOME/.cache/.theme_mode" 2>/dev/null || echo "Dark")
    if [ "$current_theme" = "Light" ]; then
        next_mode="Dark"
        # Logic for Dark mode
        wallpaper_path="$dark_wallpapers"
    else
        next_mode="Light"
        # Logic for Light mode
        wallpaper_path="$light_wallpapers"
    fi
fi

# Function to update theme mode for the next cycle
update_theme_mode() {
    echo "$next_mode" > "$HOME/.cache/.theme_mode"
}

# Function to notify user
notify_user() {
    notify-send -u low -i "$notif" " Switching to" " $1 mode"
}

# Use sed to replace the palette setting in the wallust config file
if [ "$next_mode" = "Dark" ]; then
    sed -i 's/^palette = .*/palette = "'"$pallete_dark"'"/' "$wallust_config" 
else
    sed -i 's/^palette = .*/palette = "'"$pallete_light"'"/' "$wallust_config" 
fi

# Function to set Waybar style
set_waybar_style() {
    theme="$1"
    waybar_styles="$HOME/.config/waybar/style"
    waybar_style_link="$HOME/.config/waybar/style.css"
    
    # Set fixed styles for each mode
    if [ "$theme" = "Dark" ]; then
        # Dark mode: Catppuccin Mocha Clean
        style_file="$waybar_styles/[Catppuccin] Mocha Clean.css"
    else
        # Light mode: Catppuccin Latte Clean
        style_file="$waybar_styles/[Catppuccin] Latte Clean.css"
    fi

    if [ -f "$style_file" ]; then
        ln -sf "$style_file" "$waybar_style_link"
    else
        echo "Style file not found: $style_file"
    fi
}

# Call the function after determining the mode
set_waybar_style "$next_mode"
notify_user "$next_mode"


# swaync color change
if [ "$next_mode" = "Dark" ]; then
    sed -i '/@define-color noti-bg/s/rgba([0-9]*,\s*[0-9]*,\s*[0-9]*,\s*[0-9.]*);/rgba(0, 0, 0, 0.8);/' "${swaync_style}"
	#sed -i '/@define-color noti-bg-alt/s/#.*;/#111111;/' "${swaync_style}"
else
    sed -i '/@define-color noti-bg/s/rgba([0-9]*,\s*[0-9]*,\s*[0-9]*,\s*[0-9.]*);/rgba(255, 255, 255, 0.9);/' "${swaync_style}"
	#sed -i '/@define-color noti-bg-alt/s/#.*;/#F0F0F0;/' "${swaync_style}"
fi

# ags color change
if command -v ags >/dev/null 2>&1; then    
    if [ "$next_mode" = "Dark" ]; then
        sed -i '/@define-color noti-bg/s/rgba([0-9]*,\s*[0-9]*,\s*[0-9]*,\s*[0-9.]*);/rgba(0, 0, 0, 0.4);/' "${ags_style}"
	    sed -i '/@define-color text-color/s/rgba([0-9]*,\s*[0-9]*,\s*[0-9]*,\s*[0-9.]*);/rgba(255, 255, 255, 0.7);/' "${ags_style}" 
	    sed -i '/@define-color noti-bg-alt/s/#.*;/#111111;/' "${ags_style}"
    else
        sed -i '/@define-color noti-bg/s/rgba([0-9]*,\s*[0-9]*,\s*[0-9]*,\s*[0-9.]*);/rgba(255, 255, 255, 0.4);/' "${ags_style}"
        sed -i '/@define-color text-color/s/rgba([0-9]*,\s*[0-9]*,\s*[0-9]*,\s*[0-9.]*);/rgba(0, 0, 0, 0.7);/' "${ags_style}"
	    sed -i '/@define-color noti-bg-alt/s/#.*;/#F0F0F0;/' "${ags_style}"
    fi
fi

# kitty theme change
kitty_theme_dir="$HOME/.config/kitty/kitty-themes"
if [ "$next_mode" = "Dark" ]; then
    kitty_theme="OneDark.conf"
else
    kitty_theme="Github.conf"
fi

# Update the include line in kitty.conf
sed -i "s|^include .*kitty-themes/.*\.conf|include ./kitty-themes/$kitty_theme|" "${kitty_conf}"

for pid_kitty in $(pidof kitty); do
    kill -SIGUSR1 "$pid_kitty"
done

# Set Dynamic Wallpaper for Dark or Light Mode
if [ "$next_mode" = "Dark" ]; then
    # Use live wallpaper for Dark mode
    live_wallpaper="$HOME/Videos/LiveWallpaper/yuuka-eating-blue-archive-moewalls-com.mp4"
    if [ -f "$live_wallpaper" ]; then
        # Kill existing mpvpaper instances and swww to avoid conflicts
        killall mpvpaper swww-daemon 2>/dev/null
        sleep 0.5
        # Start mpvpaper via hyprctl to ensure proper Wayland context
        hyprctl dispatch exec "mpvpaper '*' -o 'no-audio --loop --keepaspect --panscan=1.0 --hwdec=auto --scale=bilinear --vd-lavc-dr=no --video-reversal-buffer=100M --demuxer-max-bytes=50M --demuxer-max-back-bytes=10M' '$live_wallpaper'"
        # Update lock screen wallpaper to static image
        mkdir -p "$HOME/.config/hypr/wallpaper_effects"
        cp -f "$HOME/Pictures/wallpapers/Dynamic-Wallpapers/Dark/Screenshot from 2025-11-04 21-19-01.png" "$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"
    else
        # Fallback to static wallpaper if video not found
        killall mpvpaper 2>/dev/null
        next_wallpaper="$HOME/Pictures/wallpapers/Dynamic-Wallpapers/Dark/Screenshot from 2025-11-04 21-19-01.png"
        $swww "${next_wallpaper}" $effect
        # Update lock screen wallpaper
        mkdir -p "$HOME/.config/hypr/wallpaper_effects"
        cp -f "$next_wallpaper" "$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"
    fi
else
    # Use live wallpaper for Light mode
    live_wallpaper="$HOME/Videos/LiveWallpaper/hayase-yuuka-sportswear-blue-archive-wallpaperwaifu-com.mp4"
    if [ -f "$live_wallpaper" ]; then
        # Kill existing mpvpaper instances and swww to avoid conflicts
        killall mpvpaper swww-daemon 2>/dev/null
        sleep 0.5
        # Start mpvpaper via hyprctl to ensure proper Wayland context
        hyprctl dispatch exec "mpvpaper '*' -o 'no-audio --loop --keepaspect --panscan=1.0 --hwdec=auto --scale=bilinear --vd-lavc-dr=no --video-reversal-buffer=100M --demuxer-max-bytes=50M --demuxer-max-back-bytes=10M' '$live_wallpaper'"
        # Update lock screen wallpaper to static image
        mkdir -p "$HOME/.config/hypr/wallpaper_effects"
        cp -f "$HOME/Pictures/wallpapers/Dynamic-Wallpapers/Light/wallpaper48.png" "$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"
    else
        # Fallback to static wallpaper if video not found
        killall mpvpaper 2>/dev/null
        next_wallpaper="$HOME/Pictures/wallpapers/Dynamic-Wallpapers/Light/wallpaper48.png"
        # Update wallpaper using swww command
        $swww "${next_wallpaper}" $effect
        # Update lock screen wallpaper
        mkdir -p "$HOME/.config/hypr/wallpaper_effects"
        cp -f "$next_wallpaper" "$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"
    fi
fi


# Set Kvantum Manager theme & QT5/QT6 settings
if [ "$next_mode" = "Dark" ]; then
    kvantum_theme="catppuccin-mocha-blue"
    #qt5ct_color_scheme="$HOME/.config/qt5ct/colors/Catppuccin-Mocha.conf"
    #qt6ct_color_scheme="$HOME/.config/qt6ct/colors/Catppuccin-Mocha.conf"
else
    kvantum_theme="catppuccin-latte-blue"
    #qt5ct_color_scheme="$HOME/.config/qt5ct/colors/Catppuccin-Latte.conf"
    #qt6ct_color_scheme="$HOME/.config/qt6ct/colors/Catppuccin-Latte.conf"
fi

sed -i "s|^color_scheme_path=.*$|color_scheme_path=$qt5ct_color_scheme|" "$HOME/.config/qt5ct/qt5ct.conf"
sed -i "s|^color_scheme_path=.*$|color_scheme_path=$qt6ct_color_scheme|" "$HOME/.config/qt6ct/qt6ct.conf"
kvantummanager --set "$kvantum_theme"


# set the rofi color for background
if [ "$next_mode" = "Dark" ]; then
    sed -i '/^background:/s/.*/background: rgba(0,0,0,0.7);/' $wallust_rofi
else
    sed -i '/^background:/s/.*/background: rgba(255,255,255,0.9);/' $wallust_rofi
fi


# GTK themes and icons switching
set_custom_gtk_theme() {
    mode=$1
    gtk_themes_directory="$HOME/.themes"
    icon_directory="$HOME/.icons"
    color_setting="org.gnome.desktop.interface color-scheme"
    theme_setting="org.gnome.desktop.interface gtk-theme"
    icon_setting="org.gnome.desktop.interface icon-theme"

    if [ "$mode" == "Light" ]; then
        search_keywords="*Light*"
        gsettings set $color_setting 'prefer-light'
    elif [ "$mode" == "Dark" ]; then
        search_keywords="*Dark*"
        gsettings set $color_setting 'prefer-dark'
    else
        echo "Invalid mode provided."
        return 1
    fi

    themes=()
    icons=()

    while IFS= read -r -d '' theme_search; do
        themes+=("$(basename "$theme_search")")
    done < <(find "$gtk_themes_directory" -maxdepth 1 -type d -iname "$search_keywords" -print0)

    while IFS= read -r -d '' icon_search; do
        icons+=("$(basename "$icon_search")")
    done < <(find "$icon_directory" -maxdepth 1 -type d -iname "$search_keywords" -print0)

    if [ ${#themes[@]} -gt 0 ]; then
        if [ "$mode" == "Dark" ]; then
            selected_theme=${themes[RANDOM % ${#themes[@]}]}
        else
            selected_theme=${themes[$RANDOM % ${#themes[@]}]}
        fi
        echo "Selected GTK theme for $mode mode: $selected_theme"
        gsettings set $theme_setting "$selected_theme"

        # Flatpak GTK apps (themes)
        if command -v flatpak &> /dev/null; then
            flatpak --user override --filesystem=$HOME/.themes
            sleep 0.5
            flatpak --user override --env=GTK_THEME="$selected_theme"
        fi
    else
        echo "No $mode GTK theme found"
    fi

    if [ ${#icons[@]} -gt 0 ]; then
        if [ "$mode" == "Dark" ]; then
            selected_icon=${icons[RANDOM % ${#icons[@]}]}
        else
            selected_icon=${icons[$RANDOM % ${#icons[@]}]}
        fi
        echo "Selected icon theme for $mode mode: $selected_icon"
        gsettings set $icon_setting "$selected_icon"
        
        ## QT5ct icon_theme
        sed -i "s|^icon_theme=.*$|icon_theme=$selected_icon|" "$HOME/.config/qt5ct/qt5ct.conf"
        sed -i "s|^icon_theme=.*$|icon_theme=$selected_icon|" "$HOME/.config/qt6ct/qt6ct.conf"

        # Flatpak GTK apps (icons)
        if command -v flatpak &> /dev/null; then
            flatpak --user override --filesystem=$HOME/.icons
            sleep 0.5
            flatpak --user override --env=ICON_THEME="$selected_icon"
        fi
    else
        echo "No $mode icon theme found"
    fi
}

# Call the function to set GTK theme and icon theme based on mode
set_custom_gtk_theme "$next_mode"

# Update theme mode for the next cycle
update_theme_mode

# Only run WallustSwww.sh if using static wallpaper (live_wallpaper file doesn't exist)
if [ "$next_mode" = "Dark" ] && [ ! -f "$HOME/Videos/LiveWallpaper/yuuka-eating-blue-archive-moewalls-com.mp4" ]; then
    swww query || swww-daemon --format xrgb
    ${SCRIPTSDIR}/WallustSwww.sh
elif [ "$next_mode" = "Light" ] && [ ! -f "$HOME/Videos/LiveWallpaper/hayase-yuuka-sportswear-blue-archive-wallpaperwaifu-com.mp4" ]; then
    swww query || swww-daemon --format xrgb
    ${SCRIPTSDIR}/WallustSwww.sh
fi

sleep 2
# kill process
for pid1 in waybar rofi swaync ags swaybg; do
    killall "$pid1"
done

sleep 1
${SCRIPTSDIR}/Refresh.sh 

sleep 0.5
# Display notifications for theme and icon changes 
notify-send -u low -i "$notif" " Themes switched to:" " $next_mode Mode"

exit 0

