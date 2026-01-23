# Dotfiles managed by chezmoi

Dotfiles for a Hyprland-based desktop, managed with chezmoi. Focused on Waybar theming, wallust-driven colors, and optional Neovim setup.

## Overview
These dotfiles use `chezmoi` for management, `Hyprland` for window management, and `wallust` for dynamic theming. Theme switching supports Dark, Light, and Midnight modes with optional automation.

## Highlights
- **Window Manager**: Hyprland with modular configurations for animations, decorations, and keybinds.
- **Theming**: Dynamic color schemes powered by `wallust` based on the current wallpaper.
- **Theme Automation**: Systemd user services and timers to switch themes automatically or via manual toggle.
- **Status Bar**: Waybar layouts and styles with wallust-generated palettes.
- **Terminal**: Kitty theme switching coordinated with the active theme.
- **Launcher**: Rofi menus for layouts, styles, and utilities.
- **Editor**: AstroNvim-based Neovim configuration (optional).
- **Wallpapers**: Optional live wallpaper support via `mpvpaper` and static wallpapers via `swww`.

## Structure
- `private_dot_config/hypr/`: Hyprland configuration, scripts, and theme assets.
- `private_dot_config/hypr/rofi/`: Rofi configuration and themes.
- `private_dot_config/waybar/`: Waybar layouts and CSS styles.
- `private_dot_config/nvim/`: AstroNvim user configuration.
- `private_dot_config/kitty/`: Kitty terminal settings and themes.
- `private_dot_config/nushell/`: Nushell configuration.
- `private_dot_config/systemd/user/`: Services for theme automation and system monitoring.
- `private_dot_local/bin/`: Utility scripts including the theme toggler.

## Requirements
- **Core**: `chezmoi`, `hyprland`, `waybar`, `kitty`, `rofi`, `swww`, `wallust`.
- **Theme automation**: `systemd` user services, `gsettings`, `dconf`, `kvantummanager`.
- **Optional**: `mpvpaper` (live wallpapers), `playerctl` (Waybar music module), `swaync` or `ags` (notification styling).
- **Editor**: Neovim (for the AstroNvim setup under `private_dot_config/nvim/`).

## Install/Apply (chezmoi)
1. Initialize chezmoi (if not already done):
   ```bash
   chezmoi init <repository-url>
   ```
2. Review and apply changes:
   ```bash
   chezmoi apply
   ```

## Post-setup
After applying the dotfiles, run the initial setup scripts to link configs and initialize theme automation:
1. Run the symlink setup script:
   ```bash
   bash ~/.config/hypr/setup-symlinks.sh
   ```
2. The `initial-boot.sh` script runs automatically on the first Hyprland session to set wallpapers and GTK themes.
3. Enable theme automation (optional):
   ```bash
   systemctl --user daemon-reload
   systemctl --user enable --now hyprland-theme.timer
   ```

## Usage
- **Toggle Theme**: `~/.local/bin/toggle-theme` supports `light`, `dark`, `midnight`, and `auto`.
- **Keybinds**: `~/.config/hypr/configs/Keybinds.conf` and `~/.config/hypr/UserConfigs/UserKeybinds.conf`.
- **Waybar**: Layout and style switchers in `~/.config/hypr/scripts/WaybarLayout.sh` and `~/.config/hypr/scripts/WaybarStyles.sh`.
- **Monitor profiles**: See `private_dot_config/hypr/Monitor_Profiles/README` and `~/.config/hypr/scripts/MonitorProfiles.sh`.

## Notes
- **Initial Boot**: The script `initial-boot.sh` creates a marker file at `~/.config/hypr/.initial_startup_done` to ensure it only runs once.
- **Symlinks**: The setup script links `kitty` and `rofi` configs into standard `~/.config` paths.
- **One-time settings**: `run_once_before_10-apply-dconf-settings.sh` applies cursor size and text scaling via `gsettings`.
- **NixOS**: Some scripts include conditional logic for NixOS (dconf settings).

## Credits
- Base configuration inspiration from [JaKooLit](https://github.com/JaKooLit).
- Neovim configuration based on [AstroNvim](https://github.com/AstroNvim/AstroNvim).
