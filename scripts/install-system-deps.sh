#!/usr/bin/env bash
# Install packages assumed by these dotfiles.
# Scanned from: Hyprland startup/keybind scripts, Waybar modules, systemd user units,
# bash/nushell configs, Neovim bootstrap, and README.
# Supports Ubuntu 24.04-ish (JaKooLit base) and Fedora Workstation/Sway spins.

set -Eeuo pipefail

DRY_RUN=0
OPTIONAL=0
DEV=1
FLATPAK=1
AUR=0

usage() {
  cat <<'EOF'
Usage: scripts/install-system-deps.sh [options]

Options:
  --dry-run       Print commands without executing
  --optional      Also try optional GUI extras that may need COPR/PPA/manual packages
  --no-dev        Skip developer CLI/runtime packages
  --no-flatpak    Do not install Flatpak/remotes/apps
  --aur           On Arch, use yay/paru when available for AUR-ish names
  -h, --help      Show this help

Notes:
  - Ubuntu users should still run the JaKooLit Ubuntu-Hyprland installer first if
    they want the exact upstream desktop stack. This script fills/validates the
    packages these dotfiles assume.
  - Fedora is first-class here: it enables RPM Fusion and selected COPR repos
    when possible for Hyprland/AGS/Quickshell-related gaps.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --optional) OPTIONAL=1 ;;
    --no-dev) DEV=0 ;;
    --no-flatpak) FLATPAK=0 ;;
    --aur) AUR=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
  esac
  shift
done

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
run() {
  if (( DRY_RUN )); then printf 'DRY-RUN: %q ' "$@"; printf '\n'; else "$@"; fi
}

has() { command -v "$1" >/dev/null 2>&1; }

source /etc/os-release 2>/dev/null || true
OS_ID="${ID:-unknown}"
OS_LIKE="${ID_LIKE:-}"

# Commands/configs observed in this repo (kept as documentation and for checks).
SCANNED_COMMANDS=(
  ags awk bat batcat bc blueman-applet blueman-manager brightnessctl cava chezmoi cliphist
  dconf dbus-update-activation-environment ddcutil eza fcitx5 fd find fzf git grim gsettings
  heliocron hyprctl hypridle hyprland hyprlock hyprpicker hyprsunset iio-sensor-proxy jq kitty
  kvantummanager loginctl mpv mpvpaper networkmanager_dmenu nm-applet nm-connection-editor
  nm-tray notify-send nvim nwg-displays nwg-look pamixer pavucontrol playerctl podman
  podman-compose powertop python3 qalculate-gtk qs qt5ct qt6ct rg rofi slurp starship swww
  swappy swaync swaync-client systemctl thunar uwsm vim wallust waybar waybar-msg wev wf-recorder
  wl-copy wl-paste wlogout xdg-desktop-portal-hyprland xdg-open yad
)

COMMON_DEBIAN=(
  bash-completion build-essential ca-certificates curl wget git unzip zip make cmake pkg-config
  procps psmisc jq bc python3 python3-pip python3-venv lua5.1 luarocks
  dbus-user-session dconf-cli gsettings-desktop-schemas xdg-utils xdg-desktop-portal xdg-desktop-portal-gtk
  pipewire pipewire-pulse wireplumber network-manager network-manager-gnome network-manager-config-connectivity-ubuntu
  bluez blueman brightnessctl playerctl pamixer pavucontrol cava powertop iio-sensor-proxy
  fonts-noto fonts-noto-cjk fonts-noto-color-emoji fonts-font-awesome fonts-jetbrains-mono
  kitty thunar thunar-archive-plugin thunar-volman tumbler gvfs gvfs-backends
  neovim vim fzf ripgrep fd-find bat eza zoxide podman podman-compose
  fcitx5 fcitx5-hangul fcitx5-config-qt fcitx5-frontend-gtk3 fcitx5-frontend-qt5
  qt5ct qt6ct qt6-wayland qt5-style-kvantum qt6-style-kvantum qt6ct
  rofi-wayland waybar sway-notification-center wl-clipboard cliphist grim slurp swappy wf-recorder wev
  nwg-look nwg-displays wlogout swww mpv yad libnotify-bin
)
HYPR_DEBIAN=(hyprland hypridle hyprlock hyprpicker xdg-desktop-portal-hyprland hyprland-protocols)
OPTIONAL_DEBIAN=(mpvpaper ags quickshell wallust heliocron qalculate-gtk network-manager-gnome)
DEV_DEBIAN=(golang-go cargo rustc npm nodejs direnv shellcheck shfmt)

COMMON_FEDORA=(
  bash-completion @development-tools ca-certificates curl wget git unzip zip make cmake pkgconf-pkg-config
  procps-ng psmisc jq bc python3 python3-pip python3-devel lua luarocks
  dbus-daemon dconf gsettings-desktop-schemas xdg-utils xdg-desktop-portal xdg-desktop-portal-gtk
  pipewire pipewire-pulseaudio wireplumber NetworkManager NetworkManager-tui nm-connection-editor
  bluez blueman brightnessctl playerctl pamixer pavucontrol cava powertop iio-sensor-proxy
  google-noto-fonts-all google-noto-cjk-fonts google-noto-emoji-fonts fontawesome-fonts-all jetbrains-mono-fonts
  kitty thunar thunar-archive-plugin thunar-volman tumbler gvfs gvfs-mtp gvfs-smb
  neovim vim-enhanced fzf ripgrep fd-find bat eza zoxide podman podman-compose
  fcitx5 fcitx5-hangul fcitx5-configtool fcitx5-gtk fcitx5-qt
  qt5ct qt6ct kvantum qt5-qtwayland qt6-qtwayland
  rofi-wayland waybar swaync wl-clipboard cliphist grim slurp swappy wf-recorder wev
  nwg-look nwg-displays wlogout swww mpv yad libnotify
)
HYPR_FEDORA=(hyprland hypridle hyprlock hyprpicker xdg-desktop-portal-hyprland hyprland-protocols hyprsunset uwsm)
OPTIONAL_FEDORA=(mpvpaper ags quickshell wallust heliocron qalculate-gtk)
DEV_FEDORA=(golang rust cargo nodejs npm bun direnv ShellCheck shfmt)

COMMON_ARCH=(
  base-devel ca-certificates curl wget git unzip zip make cmake pkgconf procps-ng psmisc jq bc python python-pip lua luarocks
  dbus dconf gsettings-desktop-schemas xdg-utils xdg-desktop-portal xdg-desktop-portal-gtk
  pipewire pipewire-pulse wireplumber networkmanager network-manager-applet bluez blueman brightnessctl playerctl pamixer pavucontrol cava powertop iio-sensor-proxy
  noto-fonts noto-fonts-cjk noto-fonts-emoji ttf-font-awesome ttf-jetbrains-mono
  kitty thunar thunar-archive-plugin thunar-volman tumbler gvfs gvfs-mtp gvfs-smb
  neovim vim fzf ripgrep fd bat eza zoxide podman podman-compose
  fcitx5 fcitx5-hangul fcitx5-configtool fcitx5-gtk fcitx5-qt
  qt5ct qt6ct kvantum qt5-wayland qt6-wayland rofi-wayland waybar swaync wl-clipboard cliphist grim slurp swappy wf-recorder wev
  nwg-look nwg-displays wlogout swww mpv yad libnotify
)
HYPR_ARCH=(hyprland hypridle hyprlock hyprpicker xdg-desktop-portal-hyprland hyprland-protocols hyprsunset uwsm)
OPTIONAL_ARCH=(mpvpaper ags-hyprpanel-git quickshell wallust heliocron qalculate-gtk)
DEV_ARCH=(go rust nodejs npm bun direnv shellcheck shfmt)

apt_install_available() {
  local requested=("$@") available=() missing=() pkg
  for pkg in "${requested[@]}"; do
    if apt-cache show "$pkg" >/dev/null 2>&1; then available+=("$pkg"); else missing+=("$pkg"); fi
  done
  ((${#missing[@]})) && warn "apt packages not in current repos: ${missing[*]}"
  ((${#available[@]})) && run sudo apt-get install -y "${available[@]}"
}

install_apt() {
  log "Installing apt packages"
  run sudo apt-get update
  # Ubuntu 24.04's repo may lack newer Hyprland ecosystem packages; skip missing names.
  apt_install_available "${COMMON_DEBIAN[@]}" "${HYPR_DEBIAN[@]}" || warn "Some apt packages failed; JaKooLit/PPA-built Hyprland packages may already cover them."
  (( DEV )) && apt_install_available "${DEV_DEBIAN[@]}" || true
  if (( OPTIONAL )); then
    apt_install_available "${OPTIONAL_DEBIAN[@]}" || warn "Some optional apt packages are unavailable on Ubuntu; install manually if needed."
  fi
  # bat/fd command compatibility on Debian/Ubuntu.
  mkdir -p "$HOME/.local/bin"
  [[ -x /usr/bin/batcat && ! -e "$HOME/.local/bin/bat" ]] && run ln -s /usr/bin/batcat "$HOME/.local/bin/bat"
  [[ -x /usr/bin/fdfind && ! -e "$HOME/.local/bin/fd" ]] && run ln -s /usr/bin/fdfind "$HOME/.local/bin/fd"
}

install_dnf() {
  log "Enabling Fedora repos useful for multimedia/Hyprland extras"
  run sudo dnf install -y dnf-plugins-core || true
  local fedver; fedver="$(rpm -E %fedora 2>/dev/null || true)"
  if [[ -n "$fedver" ]]; then
    run sudo dnf install -y \
      "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedver}.noarch.rpm" \
      "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${fedver}.noarch.rpm" || true
  fi
  # COPRs are best-effort; package names/repo owners can change.
  if (( OPTIONAL )); then
    run sudo dnf copr enable -y solopasha/hyprland || true
    run sudo dnf copr enable -y errornointernet/quickshell || true
  fi

  log "Installing dnf packages"
  run sudo dnf install -y --skip-unavailable "${COMMON_FEDORA[@]}" "${HYPR_FEDORA[@]}" || warn "Some Fedora packages failed; check Fedora version/repos."
  (( DEV )) && run sudo dnf install -y --skip-unavailable "${DEV_FEDORA[@]}" || true
  if (( OPTIONAL )); then
    run sudo dnf install -y --skip-unavailable "${OPTIONAL_FEDORA[@]}" || warn "Some optional Fedora packages are unavailable; see missing-command check below."
  fi
}

install_pacman() {
  log "Installing pacman packages"
  run sudo pacman -Syu --needed --noconfirm "${COMMON_ARCH[@]}" "${HYPR_ARCH[@]}"
  (( DEV )) && run sudo pacman -S --needed --noconfirm "${DEV_ARCH[@]}" || true
  if (( OPTIONAL )); then
    if (( AUR )) && has yay; then run yay -S --needed --noconfirm "${OPTIONAL_ARCH[@]}"; 
    elif (( AUR )) && has paru; then run paru -S --needed --noconfirm "${OPTIONAL_ARCH[@]}";
    else run sudo pacman -S --needed --noconfirm "${OPTIONAL_ARCH[@]}" || warn "Optional/AUR packages may need yay/paru. Pass --aur."; fi
  fi
}

install_flatpak() {
  (( FLATPAK )) || return 0
  has flatpak || {
    case "$OS_ID" in
      ubuntu|debian) run sudo apt-get install -y flatpak ;;
      fedora) run sudo dnf install -y flatpak ;;
      arch|endeavouros|manjaro) run sudo pacman -S --needed --noconfirm flatpak ;;
      *) warn "flatpak not installed; skipping"; return 0 ;;
    esac
  }
  log "Configuring Flathub"
  run flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  # Apps referenced indirectly/by window rules or useful desktop defaults.
  # Warp is not packaged consistently; Flatpak is the most portable option.
  run flatpak install -y --noninteractive flathub app.zen_browser.zen || true
  run flatpak install -y --noninteractive flathub dev.warp.Warp || true
}

install_user_tools() {
  mkdir -p "$HOME/.local/bin"

  if ! has chezmoi; then
    log "Installing chezmoi to ~/.local/bin"
    if (( DRY_RUN )); then echo "DRY-RUN: sh -c 'curl -fsLS get.chezmoi.io | sh -s -- -b ~/.local/bin'"; else sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"; fi
  fi

  if (( DEV )); then
    if ! has starship; then
      log "Installing starship to ~/.local/bin"
      if (( DRY_RUN )); then echo "DRY-RUN: curl -sS https://starship.rs/install.sh | sh -s -- -b ~/.local/bin -y"; else curl -sS https://starship.rs/install.sh | sh -s -- -b "$HOME/.local/bin" -y; fi
    fi
    if ! has bun; then
      log "Installing bun"
      if (( DRY_RUN )); then echo "DRY-RUN: curl -fsSL https://bun.sh/install | bash"; else curl -fsSL https://bun.sh/install | bash; fi
    fi
    if [[ ! -s "$HOME/.nvm/nvm.sh" ]]; then
      log "Installing nvm (Node is managed by shell config via nvm)"
      if (( DRY_RUN )); then echo "DRY-RUN: curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash"; else curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash; fi
    fi
  fi

  # Rust cargo fallbacks for tools often missing from distro repos.
  if has cargo; then
    for crate in wallust heliocron hyprdynamicmonitors; do
      if ! has "$crate"; then
        warn "$crate not found. If cargo package exists for your distro, prefer that; trying cargo install $crate."
        run cargo install "$crate" || true
      fi
    done
  fi
}

post_setup() {
  log "Post setup"
  run systemctl --user daemon-reload || true
  run systemctl --user enable --now hypridle.service || true
  run systemctl --user enable --now delta-theme-startup.service delta-theme-monitor.service || true
  # These timers/services exist in dotfiles after chezmoi apply; enabling can fail before apply.
  run systemctl --user enable --now hyprland-theme.timer brightness.timer || true

  # Services commonly expected by desktop stack.
  run sudo systemctl enable --now NetworkManager || true
  run sudo systemctl enable --now bluetooth || true

  # Korean input defaults for fcitx5.
  run imsettings-switch fcitx5 || true
}

check_missing() {
  log "Checking scanned commands"
  local missing=()
  local aliases=(batcat bat fd-find fd qs quickshell nm-tray nm-applet)
  for cmd in "${SCANNED_COMMANDS[@]}"; do
    case "$cmd" in
      bat) has bat || has batcat || missing+=(bat) ;;
      fd) has fd || has fdfind || missing+=(fd) ;;
      qs) has qs || has quickshell || missing+=(qs/quickshell) ;;
      nm-tray) has nm-tray || has nm-applet || missing+=(nm-tray) ;;
      *) has "$cmd" || missing+=("$cmd") ;;
    esac
  done
  if ((${#missing[@]})); then
    warn "Still missing commands: ${missing[*]}"
    warn "Some are optional or installed by JaKooLit/manual sources (ags, qs/quickshell, mpvpaper, wallust, hyprdynamicmonitors, warp-terminal)."
  else
    log "All scanned commands are available."
  fi
}

main() {
  case "$OS_ID" in
    ubuntu|debian) install_apt ;;
    fedora) install_dnf ;;
    arch|endeavouros|manjaro) install_pacman ;;
    *)
      if [[ "$OS_LIKE" == *debian* ]]; then install_apt
      elif [[ "$OS_LIKE" == *fedora* ]]; then install_dnf
      elif [[ "$OS_LIKE" == *arch* ]]; then install_pacman
      else echo "Unsupported distro: $OS_ID ($OS_LIKE)" >&2; exit 1; fi
      ;;
  esac
  install_flatpak
  install_user_tools
  post_setup
  check_missing
  log "Done. Re-login/reboot after chezmoi apply for Hyprland/session env changes."
}

main "$@"
