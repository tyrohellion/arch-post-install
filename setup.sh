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
bashrc_file="$HOME/.bashrc"
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

# === Install paru ===
install_paru() {
  if command -v paru &>/dev/null; then
    success "paru already installed."
  else
    run_with_spinner "Installing paru" bash -c '
      sudo pacman -S --needed base-devel git --noconfirm
      git clone https://aur.archlinux.org/paru.git
      cd paru
      makepkg -si --noconfirm
      cd ..
      rm -rf paru
    '
  fi
}

# === Enable BottomUp and SudoLoop in paru.conf ===
enable_paru_options() {
  local paru_conf="/etc/paru.conf"

  # --- BottomUp in paru config ---
  if grep -qv "^#BottomUp" "$paru_conf" && grep -q "^BottomUp" "$paru_conf"; then
    success "BottomUp already enabled in paru.conf."
  else
    if grep -q "^#BottomUp" "$paru_conf"; then
      run_with_spinner "Enabling BottomUp in paru.conf" sudo sed -i 's/^#BottomUp/BottomUp/' "$paru_conf"
    else
      warn "BottomUp line not found in paru.conf — appending manually."
      echo "BottomUp" | sudo tee -a "$paru_conf" > /dev/null
    fi
    success "BottomUp enabled in paru.conf."
  fi

  # --- SudoLoop in paru config ---
  if grep -qv "^#SudoLoop" "$paru_conf" && grep -q "^SudoLoop" "$paru_conf"; then
    success "SudoLoop already enabled in paru.conf."
  else
    if grep -q "^#SudoLoop" "$paru_conf"; then
      run_with_spinner "Enabling SudoLoop in paru.conf" sudo sed -i 's/^#SudoLoop/SudoLoop/' "$paru_conf"
    else
      warn "SudoLoop line not found in paru.conf — appending manually."
      echo "SudoLoop" | sudo tee -a "$paru_conf" > /dev/null
    fi
    success "SudoLoop enabled in paru.conf."
  fi
}

# === Install packages ===
install_packages() {
  local packages=(
    base-devel steam modrinth-app-bin protonplus okular linux-prjc linux-prjc-headers heroic-games-launcher-bin
    pfetch fastfetch kvantum dunst protonup-rs mangojuice ffmpeg localsend-bin spotify figma-linux-bin
    ttf-jetbrains-mono-nerd inter-font github-desktop-bin inkscape bazaar kcolorchooser vscodium-bin
    os-prober starship firefox kdenlive gimp krita gwenview discord xdg-desktop-portal-kde brave-bin
    bottles xorg-xlsclients papirus-icon-theme plasma6-themes-chromeos-kde-git kwrited r2modman zen-browser-bin
    gamepadla-polling chromeos-gtk-theme-git konsave mangohud flatpak lmstudio proton-ge-custom-bin
  )
  run_with_spinner "Installing packages" paru -Syu --needed --noconfirm "${packages[@]}"
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
    org.gnome.Calculator
    io.gitlab.adhami3310.Footage
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
  local knsv_file="arch.knsv"
  if [[ -f "$knsv_file" ]]; then
    run_with_spinner "Applying konsave profile" konsave -i "$knsv_file"
    run_with_spinner "Activating konsave profile 'arch'" konsave -a arch
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
  local desired="GRUB_CMDLINE_LINUX_DEFAULT='nvme_load=YES zswap.enabled=0 loglevel=3 usbhid.jspoll=1 xpad.cpoll=1'"

  run_with_spinner "Updating GRUB_CMDLINE_LINUX_DEFAULT" bash -c "
    if grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' '$grub_conf'; then
      sudo sed -i \"s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|$desired|\" '$grub_conf'
    else
      echo \"$desired\" | sudo tee -a '$grub_conf' > /dev/null
    fi
    sudo grub-mkconfig -o /boot/grub/grub.cfg
  "
}

# === Customize .bashrc aliases and startup ===
customize_bashrc() {
  info "Customizing $bashrc_file..."
  local aliases=$(cat <<'EOF'
alias up="paru -Syu && protonup-rs -q && flatpak update"
alias update-grub="sudo grub-mkconfig -o /boot/grub/grub.cfg"
alias xwayland-list="xlsclients -l"
alias polling="gamepadla-polling"
alias rl-launch="echo BAKKES=1 PROMPTLESS=1 PROTON_ENABLE_WAYLAND=1 mangohud %command%"
alias paru-recent="grep -i installed /var/log/pacman.log | tail -n 30"
alias bakkes-update="if pacman -Qs bakkesmod-steam > /dev/null; then paru -Rns bakkesmod-steam && paru -Sy bakkesmod-steam --rebuild --noconfirm; else paru -Sy bakkesmod-steam --rebuild --noconfirm; fi"
eval "$(starship init bash)"
EOF
)

  while IFS= read -r line; do
    if ! grep -Fxq "$line" "$bashrc_file"; then
      echo "$line" >> "$bashrc_file"
      success "Added: $line"
    else
      info "Already exists: $line"
    fi
  done <<< "$aliases"

  if ! grep -Fxq "pfetch" "$bashrc_file"; then
    sed -i "1i pfetch" "$bashrc_file"
    success "Added pfetch at the top of $bashrc_file"
  else
    info "pfetch already at top of $bashrc_file"
  fi
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
  install_paru
  enable_paru_options
  install_packages
  install_flatpaks
  apply_konsave
  enable_os_prober
  set_grub_cmdline
  customize_bashrc
  add_environment_vars
  setup_mangohud_config
  customize_firefox
  install_grub_theme
  echo -e "\n${GREEN}All done! Reboot is recommended.${RESET}"
}
main
