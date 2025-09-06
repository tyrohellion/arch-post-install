#!/bin/bash
set -e

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
  local pid=$1
  local delay=0.1
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
  if grep -q "^\[multilib\]" "$pacman_conf"; then
    success "Multilib already enabled."
  else
    run_with_spinner "Enabling multilib" sudo sed -i 's/^#\[multilib\]/[multilib]/' "$pacman_conf"
    sudo awk '
      BEGIN { in_multilib=0 }
      /^\[multilib\]/ { in_multilib=1; print; next }
      /^\[/ && $0 !~ /\[multilib\]/ { in_multilib=0 }
      in_multilib && /^#Include = \/etc\/pacman.d\/mirrorlist/ {
        print "Include = /etc/pacman.d/mirrorlist"; next
      }
      { print }
    ' "$pacman_conf" | sudo tee "$pacman_conf.tmp" > /dev/null && sudo mv "$pacman_conf.tmp" "$pacman_conf"
    success "Multilib enabled."
  fi
}

# === Enable colored output in pacman ===
enable_color() {
  if grep -q "^Color" "$pacman_conf"; then
    success "Color output already enabled."
  else
    run_with_spinner "Enabling colored output" sudo sed -i 's/^#Color/Color/' "$pacman_conf"
  fi
}

# === Add CachyOS repo ===
add_cachyos_repo() {
  if grep -q "\[cachyos\]" "$pacman_conf"; then
    success "CachyOS repo already exists."
  else
    info "Downloading and adding CachyOS repo..."
    curl -s https://mirror.cachyos.org/cachyos-repo.tar.xz -o cachyos-repo.tar.xz
    tar xf cachyos-repo.tar.xz
    cd cachyos-repo || { error "Failed to enter cachyos-repo dir"; exit 1; }
    sudo ./cachyos-repo.sh
    cd ..
    rm -rf cachyos-repo cachyos-repo.tar.xz
    success "CachyOS repo added."
  fi
}

# === Add Cider Collective repo ===
add_cider_repo() {
  if grep -q "\[cidercollective\]" "$pacman_conf"; then
    success "Cider Collective repo already exists."
  else
    # Add GPG key if missing
    if ! pacman-key --list-keys | grep -q "A0CD6B993438E22634450CDD2A236C3F42A61682"; then
      info "Adding Cider Collective GPG key..."
      curl -s https://repo.cider.sh/ARCH-GPG-KEY | sudo pacman-key --add -
      sudo pacman-key --lsign-key A0CD6B993438E22634450CDD2A236C3F42A61682
      success "Cider Collective GPG key added."
    else
      success "Cider GPG key already added."
    fi

    info "Appending Cider Collective repo to pacman.conf..."
    sudo tee -a "$pacman_conf" > /dev/null <<EOF

# Cider Collective Repository
[cidercollective]
SigLevel = Required TrustedOnly
Server = https://repo.cider.sh/arch
EOF
    success "Cider Collective repo added."
  fi
}

# === Install yay ===
install_yay() {
  if command -v yay &>/dev/null; then
    success "yay already installed."
  else
    run_with_spinner "Installing yay" sudo pacman -Sy --noconfirm yay
  fi
}

# === Install packages ===
install_packages() {
  local packages=(
    linux-cachyos base-devel steam modrinth-app-bin stremio-linux-shell-git protonplus okular
    pfetch fastfetch kvantum dunst protonup-rs mangojuice ffmpeg volt-gui localsend-bin
    ttf-jetbrains-mono-nerd inter-font code vlc github-desktop-bin inkscape bazaar equibop-bin
    os-prober starship audacious proton-cachyos firefox kdenlive gimp krita gwenview discord kcolorchooser
    git bottles xorg-xlsclients papirus-icon-theme plasma6-themes-chromeos-kde-git kate kwrited
    gamepadla-polling chromeos-gtk-theme-git konsave mangohud flatpak cidercollective/cider
  )

  info "Installing packages..."
  if ! yay -Syu --needed --noconfirm "${packages[@]}"; then
    error "Some packages failed to install"
    exit 2
  fi
  success "All packages installed."
}

# === Install Flatpaks ===
install_flatpaks() {
  local flatpaks=(
    "com.dec05eba.gpu_screen_recorder"
    "io.github.celluloid_player.Celluloid"
  )

  for flatpak_id in "${flatpaks[@]}"; do
    if flatpak list --app | grep -q "^$flatpak_id"; then
      success "$flatpak_id already installed."
    else
      run_with_spinner "Installing $flatpak_id (flatpak)" flatpak install -y flathub "$flatpak_id"
    fi
  done
}

# === Apply konsave profile ===
apply_konsave() {
  local knsv_file="arch.knsv"
  if [[ -f "$knsv_file" ]]; then
    run_with_spinner "Applying konsave profile" konsave -i "$knsv_file"
    run_with_spinner "Activating konsave profile 'arch'" konsave -a arch
    success "Konsave profile applied."
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

  if grep -q "^GRUB_CMDLINE_LINUX_DEFAULT=" "$grub_conf"; then
    run_with_spinner "Updating GRUB_CMDLINE_LINUX_DEFAULT" sudo sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|$desired|" "$grub_conf"
  else
    echo "$desired" | sudo tee -a "$grub_conf" > /dev/null
    success "Added GRUB_CMDLINE_LINUX_DEFAULT to grub config."
  fi

  run_with_spinner "Generating GRUB config" sudo grub-mkconfig -o /boot/grub/grub.cfg
}

# === Customize .bashrc aliases and startup ===
customize_bashrc() {
  add_line() {
    local line="$1"
    if ! grep -Fxq "$line" "$bashrc_file"; then
      echo "$line" >> "$bashrc_file"
      success "Added: $line"
    else
      info "Already exists: $line"
    fi
  }

  info "Customizing $bashrc_file..."

  add_line 'alias up="yay -Syu && protonup-rs -q && flatpak update"'
  add_line 'alias update-grub="sudo grub-mkconfig -o /boot/grub/grub.cfg"'
  add_line 'alias xwayland-list="xlsclients -l"'
  add_line 'alias polling="gamepadla-polling"'
  add_line 'alias rl-launch="echo BAKKES=1 PROMPTLESS=1 PROTON_ENABLE_WAYLAND=1 DXVK_FRAME_RATE=237 mangohud %command%"'
  add_line 'alias yay-recent="grep -i installed /var/log/pacman.log | tail -n 30"'
  add_line 'alias bakkes-update="if pacman -Qs bakkesmod-steam > /dev/null; then yay -Rns bakkesmod-steam && yay -S bakkesmod-steam --rebuild --noconfirm; else yay -S bakkesmod-steam --rebuild --noconfirm; fi"'
  add_line 'eval "$(starship init bash)"'

  # Prepend pfetch at top if missing
  if ! grep -Fxq "pfetch" "$bashrc_file"; then
    sed -i "1i pfetch" "$bashrc_file"
    success "Added pfetch at the top of $bashrc_file"
  else
    info "pfetch already at top of $bashrc_file"
  fi
}

# === Add env vars to /etc/environment ===
add_env_var() {
  local key="$1"
  local value="$2"
  if grep -q "^${key}=" "$env_file"; then
    info "$key already set in $env_file."
  else
    echo "${key}=\"${value}\"" | sudo tee -a "$env_file" > /dev/null
    success "Added $key=\"$value\""
  fi
}

add_environment_vars() {
  add_env_var "ELECTRON_OZONE_PLATFORM_HINT" "auto"
}

# === MangoHud per-user config ===
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
  local repo_dir="arcadia"
  local firefox_dir="$HOME/.mozilla/firefox"
  info "Applying Firefox customizations..."

  if [[ -d $repo_dir ]]; then rm -rf "$repo_dir"; fi

  git clone --quiet https://github.com/tyrohellion/arcadia

  local profile_path
  profile_path=$(find "$firefox_dir" -maxdepth 1 -type d -name "*default-release" | head -n1)

  if [[ -d "$profile_path" ]]; then
    cp -r "$repo_dir/chrome" "$profile_path/"
    cp "$repo_dir/user.js" "$profile_path/"
    success "Custom Firefox files copied to profile: $profile_path"
  else
    warn "Firefox default-release profile not found, skipping customization."
  fi

  rm -rf "$repo_dir"
}

# === Elegant GRUB theme install ===
install_grub_theme() {
  local theme_dir="Elegant-grub2-themes"
  info "Installing Elegant GRUB theme..."

  if [[ -d $theme_dir ]]; then rm -rf "$theme_dir"; fi

  git clone --quiet https://github.com/vinceliuice/Elegant-grub2-themes
  cd "$theme_dir"
  sudo ./install.sh -t forest -p float -i left -c dark -s 1080p -l system
  cd ..
  rm -rf "$theme_dir"
  success "Elegant GRUB theme installed."
}

# === Main execution flow ===
main() {
  enable_multilib
  enable_color
  add_cachyos_repo
  add_cider_repo
  install_yay
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
