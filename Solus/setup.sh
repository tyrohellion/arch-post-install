#!/bin/bash
set -euo pipefail

if [ "$EUID" -eq 0 ]; then
    echo -e "\033[0;31m✘ Please do NOT run setup.sh with sudo — run it as your normal user.\033[0m"
    exit 1
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

info()    { echo -e "${CYAN}==> $*${RESET}"; }
success() { echo -e "${GREEN}✔ $*${RESET}"; }
warn()    { echo -e "${YELLOW}⚠ $*${RESET}"; }
error()   { echo -e "${RED}✘ $*${RESET}"; }

quiet() { "$@" >/dev/null 2>&1; }

bashrc_file="$HOME/.bashrc"
alacritty_config="$HOME/.config/alacritty/alacritty.toml"

install_packages() {
  local packages=(
    steam
    pipx
    fastfetch
    font-inter-ttf
    font-jetbrainsmono-ttf
    papirus-icon-theme
    r2modman
    mangohud
    alacritty
  )
  info "Installing packages..."
  quiet sudo eopkg it --yes-all "${packages[@]}"
  success "Packages installed."
}

install_flatpaks() {
  local flatpaks=(
    io.github.kolunmi.Bazaar
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
    org.gnome.Calculator
    com.nextcloud.desktopclient.nextcloud
    com.spotify.Client
    com.heroicgameslauncher.hgl
    org.onlyoffice.desktopeditors
    com.modrinth.ModrinthApp
    app.zen_browser.zen
    com.brave.Browser
    com.vscodium.codium
    com.vysp3r.ProtonPlus
    org.localsend.localsend_app
    org.kde.kcolorchooser
    org.kde.kdenlive
    org.gimp.GIMP
    org.kde.krita
    org.kde.gwenview
    org.kde.okular
    com.usebottles.bottles
    io.github.plrigaux.sysd-manager
  )

  info "Installing Flatpaks..."

  if ! flatpak remote-list | grep -q "^flathub-beta"; then
    quiet flatpak remote-add --if-not-exists flathub-beta https://flathub.org/beta-repo/flathub-beta.flatpakrepo
  fi

  quiet flatpak install -y --noninteractive flathub "${flatpaks[@]}"

  if ! flatpak list --app | grep -q "^com.stremio.Stremio"; then
    quiet flatpak install -y flathub-beta com.stremio.Stremio
  fi

  success "Flatpaks installed."
}

apply_konsave() {
  local knsv="solus.knsv"

  pipx install konsave

  if [[ ! -f "$knsv" ]]; then
    warn "Konsave file '$knsv' not found. Skipping."
    return
  fi

  info "Applying konsave profile..."
  quiet konsave -i "$knsv"
  quiet konsave -a solus
  success "KDE profile applied."
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

  mkdir -p "$(dirname "$alacritty_config")"

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
family = "JetBrains Mono"
style = "Regular"

[font.bold]
family = "JetBrains Mono"
style = "Bold"

[font.italic]
family = "JetBrains Mono"
style = "Italic"

[font.bold_italic]
family = "JetBrains Mono"
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

set_kernel_cmdline() {
  info "Checking kernel command line parameters..."

  local cmdline_file="/etc/kernel/cmdline.d/kernel_params.conf"
  local desired_params="nvme_load=YES usbhid.mousepoll=1 xpad.poll_interval=1"

  local current_params=""
  if [[ -f "$cmdline_file" ]]; then
    current_params="$(tr -s ' ' '\n' < "$cmdline_file" | sort)"
  fi

  local desired_sorted
  desired_sorted="$(tr -s ' ' '\n' <<< "$desired_params" | sort)"

  if [[ "$current_params" == "$desired_sorted" ]]; then
    success "Kernel parameters already set. No changes needed."
    return 0
  fi

  info "Updating kernel command line parameters..."
  quiet echo "$desired_params" | sudo tee "$cmdline_file" >/dev/null

  info "Updating boot configuration..."
  quiet sudo clr-boot-manager update

  success "Kernel parameters updated."
}

set_ntsync_autoload() {
  info "Checking NTSYNC auto-load configuration..."

  local module_name="ntsync"
  local config_file="/etc/modules-load.d/${module_name}.conf"

  if [[ -f "$config_file" ]] && grep -qx "$module_name" "$config_file"; then
    success "NTSYNC is already configured for auto-load."
    return 0
  fi

  info "Configuring NTSYNC to load at boot..."
  sudo mkdir -p /etc/modules-load.d

  echo "$module_name" | sudo tee "$config_file" > /dev/null

  if ! lsmod | grep -q "$module_name"; then
    info "Loading module for current session..."
    sudo modprobe "$module_name"
  fi

  success "NTSYNC auto-load enabled."
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

main() {
  apply_konsave
  setup_mangohud_config
  customize_alacritty_config
  set_kernel_cmdline
  set_ntsync_autoload
  customize_firefox
  success "All done! Reboot recommended."
}

main
