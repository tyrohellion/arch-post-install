#!/bin/bash
set -euo pipefail

# Prevent running as root
if [ "$EUID" -eq 0 ]; then
    echo -e "\033[0;31m✘ Please do NOT run setup.sh with sudo — run it as your normal user.\033[0m"
    exit 1
fi

# === Colors for output ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

info()    { echo -e "${CYAN}==> $*${RESET}"; }
success() { echo -e "${GREEN}✔ $*${RESET}"; }
warn()    { echo -e "${YELLOW}⚠ $*${RESET}"; }
error()   { echo -e "${RED}✘ $*${RESET}"; }

spinner() {
  local pid=$1 delay=0.2
  local spinstr='|/-\'
  while kill -0 "$pid" 2>/dev/null; do
    local temp=${spinstr#?}
    printf " [%c]  " "$spinstr"
    spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b\b"
  done
  printf "      \b\b\b\b\b\b"
}

run_with_spinner() {
  local msg="$1"
  shift
  info "$msg"
  "$@" & spinner $!
  wait $! || { error "Failed: $msg"; exit 1; }
  success "$msg done."
}

# === Paths ===
pacman_conf="/etc/pacman.conf"
grub_conf="/etc/default/grub"
fish_config="/usr/share/cachyos-fish-config/cachyos-config.fish"
alacritty_config="$HOME/.config/alacritty/alacritty.toml"
env_file="/etc/environment"

# === Enable multilib repo ===
enable_multilib() {
  if grep -Eq '^[[:space:]]*\[multilib\]' "$pacman_conf"; then
    success "Multilib already enabled."
  else
    run_with_spinner "Enabling multilib" bash -c "
      # Uncomment the [multilib] line (with or without spaces)
      sudo sed -i 's/^[[:space:]]*#\s*\[multilib\]/[multilib]/' '$pacman_conf'

      # Uncomment the Include line just below it, if commented
      sudo sed -i '/\[multilib\]/,/^\\[/ s/^[[:space:]]*#\s*Include/Include/' '$pacman_conf'
    "
    success "Multilib repository enabled."
  fi
}

# === Enable colored output ===
enable_color() {
  if grep -Eq '^[[:space:]]*Color' "$pacman_conf"; then
    success "Color output already enabled."
  else
    if grep -Eq '^[[:space:]]*#\s*Color' "$pacman_conf"; then
      run_with_spinner "Enabling colored output" sudo sed -i 's/^[[:space:]]*#\s*Color/Color/' "$pacman_conf"
    else
      warn "No Color line found in $pacman_conf — adding it manually."
      echo -e "\nColor" | sudo tee -a "$pacman_conf" > /dev/null
    fi
    success "Color output enabled."
  fi
}

sudo pacman -Syu yay --needed --noconfirm

# === Install packages ===
install_packages() {
  local packages=(
    base-devel steam modrinth-app-bin protonplus okular linux-zen heroic-games-launcher-bin onlyoffice-bin 
    pfetch fastfetch kvantum dunst protonup-rs mangojuice ffmpeg localsend-bin spotify figma-linux-bin discord
    ttf-jetbrains-mono-nerd inter-font github-desktop-bin inkscape bazaar kcolorchooser vscodium-bin nextcloud
    os-prober firefox kdenlive gimp krita gwenview xdg-desktop-portal-kde brave-bin tailscale nextcloud-client
    bottles xorg-xlsclients papirus-icon-theme plasma6-themes-chromeos-kde-git kwrited r2modman zen-browser-bin
    gamepadla-polling chromeos-gtk-theme-git konsave mangohud flatpak lmstudio proton-ge-custom-bin gnome-calculator
  )
  run_with_spinner "Installing packages" yay -Syu --needed --noconfirm "${packages[@]}"
}

# === Install Flatpaks ===
install_flatpaks() {
  local flatpaks=(
    com.dec05eba.gpu_screen_recorder
    io.github.celluloid_player.Celluloid
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
  )

  if ! flatpak remote-list | grep -q "^flathub-beta"; then
    run_with_spinner "Adding flathub-beta remote" flatpak remote-add --if-not-exists flathub-beta https://flathub.org/beta-repo/flathub-beta.flatpakrepo
  else
    success "flathub-beta remote already exists."
  fi

  run_with_spinner "Installing Flatpaks" flatpak install -y --noninteractive flathub "${flatpaks[@]}"

  local stremio_id="com.stremio.Stremio"
  if ! flatpak list --app | grep -q "^$stremio_id"; then
    run_with_spinner "Installing $stremio_id (flathub-beta)" flatpak install -y flathub-beta "$stremio_id"
  else
    success "$stremio_id already installed."
  fi
}

# === Apply konsave profile ===
apply_konsave() {
  local knsv_file="cachy.knsv"
  if [[ -f "$knsv_file" ]]; then
    run_with_spinner "Applying konsave profile" konsave -i "$knsv_file"
    run_with_spinner "Activating konsave profile 'cachy'" konsave -a cachy
  else
    warn "Konsave file '$knsv_file' not found, skipping."
  fi
}

# === Enable OS prober in GRUB ===
enable_os_prober() {
  if grep -q "^#GRUB_DISABLE_OS_PROBER=false" "$grub_conf"; then
    run_with_spinner "Enabling OS prober for GRUB" sudo sed -i 's/^#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' "$grub_conf"
  else
    success "GRUB OS prober already enabled or set."
  fi
}

# === Set GRUB_CMDLINE_LINUX_DEFAULT ===
set_grub_cmdline() {
  local desired="GRUB_CMDLINE_LINUX_DEFAULT='nowatchdog nvme_load=YES zswap.enabled=0 splash loglevel=3 usbhid.jspoll=1 xpad.cpoll=1'"

  run_with_spinner "Updating GRUB_CMDLINE_LINUX_DEFAULT" bash -c "
    if grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' '$grub_conf'; then
      sudo sed -i \"s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|$desired|\" '$grub_conf'
    else
      echo \"$desired\" | sudo tee -a '$grub_conf' > /dev/null
    fi
    sudo grub-mkconfig -o /boot/grub/grub.cfg
  "
}

# === Customize fish config aliases and startup ===
customize_fish_config() {
  info "Overwriting $fish_config..."

  sudo tee "$fish_config" > /dev/null <<'EOF'
## Source from conf.d before our fish config
source /usr/share/cachyos-fish-config/conf.d/done.fish

## Set values
## Run fastfetch as welcome message
function fish_greeting
    pfetch
end

# Format man pages
set -x MANROFFOPT "-c"
set -x MANPAGER "sh -c 'col -bx | bat -l man -p'"

# Set settings for https://github.com/franciscolourenco/done
set -U __done_min_cmd_duration 10000
set -U __done_notification_urgency_level low

## Environment setup
# Apply .profile: use this to put fish compatible .profile stuff in
if test -f ~/.fish_profile
  source ~/.fish_profile
end

# Add ~/.local/bin to PATH
if test -d ~/.local/bin
    if not contains -- ~/.local/bin $PATH
        set -p PATH ~/.local/bin
    end
end

# Add depot_tools to PATH
if test -d ~/Applications/depot_tools
    if not contains -- ~/Applications/depot_tools $PATH
        set -p PATH ~/Applications/depot_tools
    end
end

## Functions
# Functions needed for !! and !$ https://github.com/oh-my-fish/plugin-bang-bang
function __history_previous_command
  switch (commandline -t)
  case "!"
    commandline -t $history[1]; commandline -f repaint
  case "*"
    commandline -i !
  end
end

function __history_previous_command_arguments
  switch (commandline -t)
  case "!"
    commandline -t ""
    commandline -f history-token-search-backward
  case "*"
    commandline -i '$'
  end
end

if [ "$fish_key_bindings" = fish_vi_key_bindings ];
  bind -Minsert ! __history_previous_command
  bind -Minsert '$' __history_previous_command_arguments
else
  bind ! __history_previous_command
  bind '$' __history_previous_command_arguments
end

# Fish command history
function history
    builtin history --show-time='%F %T '
end

function backup --argument filename
    cp $filename $filename.bak
end

# Copy DIR1 DIR2
function copy
    set count (count $argv | tr -d \n)
    if test "$count" = 2; and test -d "$argv[1]"
        set from (echo $argv[1] | trim-right /)
        set to (echo $argv[2])
        command cp -r $from $to
    else
        command cp $argv
    end
end

## Useful aliases
# Replace ls with eza
alias ls='eza -al --color=always --group-directories-first --icons'
alias la='eza -a --color=always --group-directories-first --icons'
alias ll='eza -l --color=always --group-directories-first --icons'
alias lt='eza -aT --color=always --group-directories-first --icons'
alias l.="eza -a | grep -e '^\.'"

# Common use
alias fixpacman="sudo rm /var/lib/pacman/db.lck"
alias tarnow='tar -acf '
alias untar='tar -zxvf '
alias wget='wget -c '
alias psmem='ps auxf | sort -nr -k 4'
alias psmem10='ps auxf | sort -nr -k 4 | head -10'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ......='cd ../../../../..'
alias dir='dir --color=auto'
alias vdir='vdir --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias hw='hwinfo --short'
alias big="expac -H M '%m\t%n' | sort -h | nl"
alias gitpkg='pacman -Q | grep -i "\-git" | wc -l'

# Get fastest mirrors
alias mirror="sudo cachyos-rate-mirrors"

# Cleanup orphaned packages
alias cleanup='sudo pacman -Rns (pacman -Qtdq)'

# Get the error messages from journalctl
alias jctl="journalctl -p 3 -xb"

alias up="yay -Syu && protonup-rs -q && flatpak update"
alias update-grub="sudo grub-mkconfig -o /boot/grub/grub.cfg"
alias xwayland-list="xlsclients -l"
alias firmware-update="sudo fwupdmgr refresh && sudo fwupdmgr get-updates && sudo fwupdmgr update"
alias polling="gamepadla-polling"
alias tailstart="sudo systemctl start tailscaled"
alias rl-launch="echo BAKKES=1 PROMPTLESS=1 PROTON_ENABLE_WAYLAND=1 mangohud %command%"
alias yay-recent="grep -i installed /var/log/pacman.log | tail -n 200"
function bakkes-update
    if pacman -Qs bakkesmod-steam > /dev/null
        yay -Rns bakkesmod-steam
        yay -Sy bakkesmod-steam --rebuild --noconfirm
    else
        yay -Sy bakkesmod-steam --rebuild --noconfirm
    end
end
EOF

  success "Wrote new config to $fish_config"
}

# === Customize alacritty config ===
customize_alacritty_config() {
  info "Overwriting $alacritty_config..."

  sudo tee "$alacritty_config" > /dev/null <<'EOF'
[env]
TERM = "xterm-256color"
WINIT_X11_SCALE_FACTOR = "1"

[window]
padding = { x = 16, y = 8 }
dynamic_padding = false
decorations = "full"
title = "Alacritty@CachyOS"
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
background = "0x2E3440"
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

  success "Wrote new config to $alacritty_config"
}

# === Add env vars ===
add_env_var() {
  local key="$1" value="$2"
  if grep -q "^${key}=" "$env_file"; then
    info "$key already set in $env_file."
  else
    echo "${key}=\"${value}\"" | sudo tee -a "$env_file" > /dev/null
    success "Added $key=\"$value\""
  fi
}
add_environment_vars() { add_env_var "ELECTRON_OZONE_PLATFORM_HINT" "auto"; }

# === MangoHud config ===
setup_mangohud_config() {
  info "Creating MangoHud config..."
  mkdir -p "$HOME/.config/MangoHud"
  cat > "$HOME/.config/MangoHud/MangoHud.conf" <<'EOF'
# Config Generated by MangoJuice #
legacy_layout=false
blacklist=protonplus,lsfg-vk-ui,bazzar,gnome-calculator,pamac-manager,lact,ghb,bitwig-studio,ptyxis,yumex
gpu_stats
gpu_load_change
cpu_stats
cpu_load_change
fps
fps_color_change
fps_metrics=avg,0.01
resolution
display_server
engine_short_names
present_mode
wine
winesync
toggle_logging=Shift_L+F2
toggle_hud_position=Shift_R+F11
output_folder=$HOME/
fps_limit_method=late
toggle_fps_limit=Shift_L+F1
vsync=1
horizontal
horizontal_stretch=0
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
  success "MangoHud config written to $HOME/.config/MangoHud/MangoHud.conf"
}

# === Firefox customization ===
customize_firefox() {
  local firefox_dir="$HOME/.mozilla/firefox"
  local tmpdir
  tmpdir=$(mktemp -d)
  info "Applying Firefox customizations..."

  git clone --quiet --depth=1 https://github.com/tyrohellion/arcadia "$tmpdir"

  local profile_path
  profile_path=$(find "$firefox_dir" -maxdepth 1 -type d -name "*default-release" | head -n1)

  if [[ -d "$profile_path" ]]; then
    cp -r "$tmpdir/chrome" "$profile_path/"
    cp "$tmpdir/user.js" "$profile_path/"
    success "Custom Firefox files copied to profile: $profile_path"
  else
    warn "Firefox default-release profile not found, skipping customization."
  fi

  rm -rf "$tmpdir"
}

# === Elegant GRUB theme install ===
install_grub_theme() {
  local tmpdir
  tmpdir=$(mktemp -d)
  info "Installing Elegant GRUB theme..."

  git clone --quiet --depth=1 https://github.com/vinceliuice/Elegant-grub2-themes "$tmpdir"
  (cd "$tmpdir" && sudo ./install.sh -t forest -p float -i left -c dark -s 1080p -l system)
  rm -rf "$tmpdir"
  success "Elegant GRUB theme installed."
}

# === Main ===
main() {
  enable_multilib
  enable_color
  install_packages
  install_flatpaks
  apply_konsave
  enable_os_prober
  set_grub_cmdline
  customize_fish_config
  customize_alacritty_config
  add_environment_vars
  setup_mangohud_config
  customize_firefox
  install_grub_theme
  echo -e "\n${GREEN}All done! Reboot is recommended.${RESET}"
}
main
