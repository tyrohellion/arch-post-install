#!/bin/bash
set -euo pipefail

# Prevent running as root
if [ "$EUID" -eq 0 ]; then
    echo -e "\033[0;31m✘ Please do NOT run setup.sh with sudo — run it as your normal user.\033[0m"
    exit 1
fi

# ===================== COLORS =====================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

info()    { echo -e "${CYAN}==> $*${RESET}"; }
success() { echo -e "${GREEN}✔ $*${RESET}"; }
warn()    { echo -e "${YELLOW}⚠ $*${RESET}"; }
error()   { echo -e "${RED}✘ $*${RESET}"; }

# ===================== QUIET EXEC WRAPPER =====================
quiet() { "$@" >/dev/null 2>&1; }

# ===================== PATHS =====================
pacman_conf="/etc/pacman.conf"
grub_conf="/etc/default/grub"
bashrc_file="$HOME/.bashrc"
alacritty_config="$HOME/.config/alacritty/alacritty.toml"
env_file="/etc/environment"

# ===================== FUNCTIONS =====================

enable_multilib() {
  if grep -Eq '^[[:space:]]*\[multilib\]' "$pacman_conf"; then
    success "Multilib already enabled."
  else
    info "Enabling multilib..."
    quiet sudo sed -i 's/^[[:space:]]*#\s*\[multilib\]/[multilib]/' "$pacman_conf"
    quiet sudo sed -i '/\[multilib\]/,/^\\[/ s/^[[:space:]]*#\s*Include/Include/' "$pacman_conf"
    success "Multilib enabled."
  fi
}

enable_color() {
  if grep -Eq '^[[:space:]]*Color' "$pacman_conf"; then
    success "Pacman color already enabled."
  else
    info "Enabling pacman color..."
    if grep -Eq '^[[:space:]]*#\s*Color' "$pacman_conf"; then
      quiet sudo sed -i 's/^[[:space:]]*#\s*Color/Color/' "$pacman_conf"
    else
      echo -e "\nColor" | sudo tee -a "$pacman_conf" >/dev/null
    fi
    success "Pacman color enabled."
  fi
}

enable_makepkg_no_debug() {
  local makepkg_conf="/etc/makepkg.conf"

  if grep -Eq '^[[:space:]]*OPTIONS=.*!debug' "$makepkg_conf"; then
    success "makepkg debug already disabled."
    return
  fi

  if grep -Eq '^[[:space:]]*OPTIONS=.*\bdebug\b' "$makepkg_conf"; then
    info "Disabling makepkg debug option..."

    quiet sudo sed -i \
      's/^\([[:space:]]*OPTIONS=.*\)\bdebug\b/\1!debug/' \
      "$makepkg_conf"

    success "makepkg debug option disabled."
  else
    success "makepkg debug option not present; nothing to change."
  fi
}

install_yay() {
  if command -v yay >/dev/null; then
    success "yay already installed."
    return
  fi

  info "Installing yay..."
  sudo pacman -Syu --needed --noconfirm git base-devel
  git clone https://aur.archlinux.org/yay-bin.git
  bash -c "cd yay-bin && makepkg -si --noconfirm"
  rm -rf yay-bin
  success "yay installed."
}

install_packages() {
  local packages=(
    base-devel steam modrinth-app-bin protonplus linux-zen heroic-games-launcher-bin onlyoffice-bin
    pfetch fastfetch mangojuice ffmpeg localsend-bin figma-linux-bin alacritty ttf-noto-sans-cjk-vf helium-browser-bin
    ttf-jetbrains-mono-nerd inter-font github-desktop-bin inkscape bazaar kcolorchooser jellyfin-desktop
    os-prober starship kdenlive gimp krita gwenview xdg-desktop-portal-kde brave-bin kjournald kexi vscodium-bin
    bottles xorg-xlsclients papirus-icon-theme zen-browser-bin ffmpegthumbs openssh okular drawy-git r2modman-bin
    gamepadla-polling konsave mangohud flatpak proton-ge-custom-bin gnome-calculator systemdgenie fwupd fetchmirrors
  )
  info "Installing packages..."
  yay -Syu --needed --noconfirm "${packages[@]}"
  success "Packages installed."
}

install_flatpaks() {
  local flatpaks=(
    com.dec05eba.gpu_screen_recorder
    com.discordapp.Discord
    io.gitlab.adhami3310.Converter
    io.github.nokse22.asciidraw
    org.gnome.gitlab.YaLTeR.VideoTrimmer
    com.github.unrud.VideoDownloader
    com.github.tenderowl.frog
    org.gnome.design.Lorem
    com.authormore.penpotdesktop
    com.github.taiko2k.avvie
    com.github.tchx84.Flatseal
    io.github.flattool.Warehouse
    io.github.josephmawa.SpellingBee
    io.github.wartybix.Constrict
    org.gnome.Decibels
    org.gnome.design.Lorem
    io.gitlab.theevilskeleton.Upscaler
    org.kde.haruna
    com.nextcloud.desktopclient.nextcloud
  )

  info "Installing Flatpaks..."

  if ! flatpak remote-list | grep -q "^flathub-beta"; then
    flatpak remote-add --if-not-exists --system flathub-beta https://flathub.org/beta-repo/flathub-beta.flatpakrepo
  fi

  flatpak install -y --noninteractive --system flathub "${flatpaks[@]}"

  if ! flatpak list --app | grep -q "^com.stremio.Stremio"; then
    flatpak install -y flathub-beta --system com.stremio.Stremio
  fi

  success "Flatpaks installed."
}

apply_konsave() {
  local knsv="arch.knsv"

  if [[ ! -f "$knsv" ]]; then
    warn "Konsave file '$knsv' not found. Skipping."
    return
  fi

  info "Applying konsave profile..."
  quiet konsave -i "$knsv"
  quiet konsave -a arch
  success "KDE profile applied."
}

enable_os_prober() {
  info "Ensuring GRUB OS prober is enabled..."
  quiet sudo sed -i 's/^#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' "$grub_conf" || true
  success "GRUB OS prober enabled."
}

set_grub_cmdline() {
  info "Updating GRUB kernel parameters..."
  quiet sudo sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT='nowatchdog nvme_load=YES zswap.enabled=0 splash quiet loglevel=3 usbhid.mousepoll=1 xpad.poll_interval=1'|" "$grub_conf"
  quiet sudo grub-mkconfig -o /boot/grub/grub.cfg
  success "GRUB updated."
}

customize_bashrc() {
  info "Updating .bashrc..."

  local lines=$(cat <<'EOF'
alias up="yay -Syu && flatpak update && sudo grub-mkconfig -o /boot/grub/grub.cfg && sudo fwupdmgr refresh && sudo fwupdmgr get-updates && sudo fwupdmgr update"
alias rank-mirrors="fetchmirrors -c US --noconfirm"
alias update-grub="sudo grub-mkconfig -o /boot/grub/grub.cfg"
alias xwayland-list="xlsclients -l"
alias firmware-update="sudo fwupdmgr refresh --force && sudo fwupdmgr get-updates && sudo fwupdmgr update"
alias polling="gamepadla-polling"
alias tailstart="sudo systemctl start tailscaled"
alias rl-launch="echo BAKKES=1 PROMPTLESS=1 PROTON_ENABLE_WAYLAND=1 mangohud %command%"
alias yay-recent="grep -i installed /var/log/pacman.log | tail -n 200"
alias bakkes-update="if pacman -Qs bakkesmod-steam > /dev/null; then yay -Rns bakkesmod-steam && yay -Sy bakkesmod-steam --rebuild --noconfirm; else yay -Sy bakkesmod-steam --rebuild --noconfirm; fi"
eval "$(starship init bash)"
EOF
)

  while IFS= read -r line; do
    grep -Fxq "$line" "$bashrc_file" || echo "$line" >> "$bashrc_file"
  done <<< "$lines"

  if ! grep -Fxq "pfetch" "$bashrc_file"; then
    sed -i "1i pfetch" "$bashrc_file"
  fi

  success ".bashrc customized."
}

add_env_var() {
  local key="$1" value="$2"
  if grep -q "^${key}=" "$env_file"; then
    success "$key already set."
  else
    echo "${key}=\"${value}\"" | sudo tee -a "$env_file" >/dev/null
    success "Added $key."
  fi
}

add_environment_vars() {
  add_env_var "ELECTRON_OZONE_PLATFORM_HINT" "auto"
}

setup_mangohud_config() {
  info "Creating MangoHud config..."
  mkdir -p "$HOME/.config/MangoHud"
  cat > "$HOME/.config/MangoHud/MangoHud.conf" <<'EOF'
  legacy_layout=false
  horizontal
  horizontal_stretch=0
  blacklist=protonplus,lsfg-vk-ui,bazzar,gnome-calculator,pamac-manager,lact,ghb,bitwig-studio,ptyxis,yumex
  gpu_stats
  gpu_load_change
  cpu_stats
  cpu_load_change
  fps
  fps_color_change
  fps_metrics=avg,0.01
  wine
  #frame_timing
  round_corners=4
  resolution
  display_server
  engine_short_names
  present_mode
  winesync
  toggle_logging=Shift_L+F2
  toggle_hud_position=Shift_R+F11
  output_folder=$HOME/
  fps_limit_method=late
  toggle_fps_limit=Shift_L+F1
  vsync=1
  cellpadding_y=0.25
  background_alpha=0.6
  position=top-left
  toggle_hud=Shift_R+F12
  font_size=18
  gpu_text=GPU
  gpu_color=2e9762
  cpu_text=CPU
  cpu_color=2e97cb
  fps_value=30,60
  fps_color=b22222,fdfd09,39f900
  gpu_load_value=50,90
  gpu_load_color=ffffff,ffaa7f,cc0000
  cpu_load_value=50,90
  cpu_load_color=ffffff,ffaa7f,cc0000
  background_color=000000
  frametime_color=fa8000
  vram_color=ad64c1
  ram_color=c26693
  wine_color=eb5b5b
  engine_color=eb5b5b
  text_color=ffffff
  media_player_color=ffffff
  network_color=e07b85
  battery_color=92e79a
  media_player_format={title};{artist};{album}
EOF
  success "MangoHud config written."
}

customize_alacritty_config() {
  info "Writing Alacritty config..."

  # Ensure directory exists
  mkdir -p "$(dirname "$alacritty_config")"

  # Overwrite config
  cat > "$alacritty_config" <<'EOF'
[env]
TERM = "xterm-256color"
WINIT_X11_SCALE_FACTOR = "1"

[window]
padding = { x = 16, y = 8 }
dynamic_padding = false
decorations = "full"
title = "alacritty"
opacity = 0.99
decorations_theme_variant = "Dark"

[window.dimensions]
columns = 140
lines = 35

[window.class]
instance = "Alacritty"
general = "Alacritty"

[scrolling]
history = 10000
multiplier = 3

[colors]
draw_bold_text_with_bright_colors = true

[colors.primary]
background = "0x15181e"
foreground = "0xD8DEE9"

[colors.normal]
black = "0x3B4252"
red = "0xBF616A"
green = "0xA3BE8C"
yellow = "0xEBCB8B"
blue = "0x81A1C1"
magenta = "0xB48EAD"
cyan = "0x88C0D0"
white = "0xE5E9F0"

[colors.bright]
black = "0x4C566A"
red = "0xBF616A"
green = "0xA3BE8C"
yellow = "0xEBCB8B"
blue = "0x81A1C1"
magenta = "0xB48EAD"
cyan = "0x8FBCBB"
white = "0xECEFF4"

[font]
size = 12

[font.normal]
family = "JetBrainsMono Nerd Font"
style = "Regular"

[font.bold]
family = "JetBrainsMono Nerd Font"
style = "Bold"

[font.italic]
family = "JetBrainsMono Nerd Font"
style = "Italic"

[font.bold_italic]
family = "JetBrainsMono Nerd Font"
style = "Bold Italic"

[selection]
semantic_escape_chars = ",│`|:\"' ()[]{}<>\t"
save_to_clipboard = true

[cursor]
style = "Underline"
vi_mode_style = "None"
unfocused_hollow = true
thickness = 0.15

[mouse]
hide_when_typing = true

[[mouse.bindings]]
mouse = "Middle"
action = "PasteSelection"

[keyboard]
[[keyboard.bindings]]
key = "Paste"
action = "Paste"

[[keyboard.bindings]]
key = "Copy"
action = "Copy"

[[keyboard.bindings]]
key = "L"
mods = "Control"
action = "ClearLogNotice"

[[keyboard.bindings]]
key = "L"
mods = "Control"
mode = "~Vi"
chars = "\f"

[[keyboard.bindings]]
key = "PageUp"
mods = "Shift"
mode = "~Alt"
action = "ScrollPageUp"

[[keyboard.bindings]]
key = "PageDown"
mods = "Shift"
mode = "~Alt"
action = "ScrollPageDown"

[[keyboard.bindings]]
key = "Home"
mods = "Shift"
mode = "~Alt"
action = "ScrollToTop"

[[keyboard.bindings]]
key = "End"
mods = "Shift"
mode = "~Alt"
action = "ScrollToBottom"

[[keyboard.bindings]]
key = "V"
mods = "Control|Shift"
action = "Paste"

[[keyboard.bindings]]
key = "C"
mods = "Control|Shift"
action = "Copy"

[[keyboard.bindings]]
key = "F"
mods = "Control|Shift"
action = "SearchForward"

[[keyboard.bindings]]
key = "B"
mods = "Control|Shift"
action = "SearchBackward"

[[keyboard.bindings]]
key = "C"
mods = "Control|Shift"
mode = "Vi"
action = "ClearSelection"

[[keyboard.bindings]]
key = "Key0"
mods = "Control"
action = "ResetFontSize"

[general]
live_config_reload = true
working_directory = "None"
EOF

  success "Alacritty config written to $alacritty_config"
}

customize_firefox() {
  info "Customizing Firefox..."
  local firefox_dir="$HOME/.mozilla/firefox"
  local tmp=$(mktemp -d)

  quiet git clone --depth=1 https://github.com/tyrohellion/arcadia "$tmp"

  local profile
  profile=$(find "$firefox_dir" -maxdepth 1 -type d -name "*default-release" | head -n 1)

  if [[ -d "$profile" ]]; then
    quiet cp -r "$tmp/chrome" "$profile/"
    quiet cp "$tmp/user.js" "$profile/"
    success "Firefox theme applied."
  else
    warn "Firefox profile not found. Skipping."
  fi

  quiet rm -rf "$tmp"
}

install_grub_theme() {
  info "Installing GRUB theme..."
  local tmp=$(mktemp -d)

  quiet git clone --depth=1 https://github.com/vinceliuice/Elegant-grub2-themes "$tmp"
  quiet bash -c "cd $tmp && sudo ./install.sh -t mojave -p float -i left -c dark -s 2k -l system"
  quiet rm -rf "$tmp"

  success "GRUB theme installed."
}

# ===================== MAIN =====================

main() {
  enable_multilib
  enable_color
  enable_makepkg_no_debug
  install_yay
  install_packages
  install_flatpaks
  apply_konsave
  enable_os_prober
  set_grub_cmdline
  customize_bashrc
  #add_environment_vars ---- disabled because I don't have any env variables in use at the moment
  setup_mangohud_config
  customize_alacritty_config
  #customize_firefox ---- disabled until new firefox xdg spec is implemented in function
  #install_grub_theme
  success "All done! Reboot recommended."
}

main
