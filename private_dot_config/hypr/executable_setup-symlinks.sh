#!/bin/bash

set -e

HYPR_CONFIG="$HOME/.config/hypr"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"

log() {
  printf '%s\n' "$1"
}

link_dir_with_backup() {
  local source_dir="$1"   # e.g. $HYPR_CONFIG/kitty
  local target_dir="$2"   # e.g. $HOME/.config/kitty
  local name="$3"         # label for logs

  if [ ! -d "$source_dir" ]; then
    log "  [$name] Source dir not found: $source_dir (skipping)"
    return
  fi

  # If target is a symlink, remove it so we can recreate it.
  if [ -L "$target_dir" ]; then
    log "  [$name] Removing existing symlink: $target_dir"
    rm "$target_dir"
  elif [ -e "$target_dir" ]; then
    # If it exists and is not a symlink, back it up once.
    local backup="${target_dir}.bak.hypr_setup"
    if [ ! -e "$backup" ]; then
      log "  [$name] Backing up existing: $target_dir -> $backup"
      mv "$target_dir" "$backup"
    else
      log "  [$name] Existing backup already exists: $backup (leaving $target_dir as-is, skipping)"
      return
    fi
  fi

  ln -s "$source_dir" "$target_dir"
  log "  [$name] ✓ Linked: $target_dir -> $source_dir"
}

log "Setting up symbolic links..."

# Create directories if they don't exist
mkdir -p "$SYSTEMD_USER_DIR"

# ---------------------------------------------------------------------------
# systemd user services/timers
# ---------------------------------------------------------------------------
log "Linking systemd files to $SYSTEMD_USER_DIR..."
if [ -d "$HYPR_CONFIG/systemd" ]; then
    for file in "$HYPR_CONFIG/systemd"/*; do
        if [ -f "$file" ]; then
            file_name=$(basename "$file")
            target="$SYSTEMD_USER_DIR/$file_name"
            
            if [ -L "$target" ]; then
                log "  Removing existing symlink: $file_name"
                rm "$target"
            elif [ -e "$target" ]; then
                log "  Warning: $file_name exists and is not a symlink, skipping"
                continue
            fi
            
            ln -s "$file" "$target"
            log "  ✓ Linked: $file_name"
        fi
    done
else
    log "  No systemd directory found at $HYPR_CONFIG/systemd"
fi

# ---------------------------------------------------------------------------
# kitty & rofi configs
# Keep kitty/rofi configs under $HYPR_CONFIG and link from ~/.config
# ---------------------------------------------------------------------------

log "Linking kitty and rofi configs under $HYPR_CONFIG..."

# kitty:   $HYPR_CONFIG/kitty -> $HOME/.config/kitty
link_dir_with_backup "$HYPR_CONFIG/kitty" "$HOME/.config/kitty" "kitty"

# rofi:    $HYPR_CONFIG/rofi -> $HOME/.config/rofi
link_dir_with_backup "$HYPR_CONFIG/rofi" "$HOME/.config/rofi" "rofi"

log ""
log "Done! To apply changes and enable automation:"
log "  systemctl --user daemon-reload"
log "  systemctl --user enable --now hyprland-theme.timer"
log "  systemctl --user enable --now hyprland-theme@sunset-dark"
log "  systemctl --user enable --now hyprland-theme@sunrise-light"
