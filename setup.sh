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
  if grep -qF "[multilib]" "$pacman_conf"; then
    success "Multilib already enabled."
  else
    run_with_spinner "Enabling multilib" sudo bash -c "
      sed -i 's/^#\[multilib\]/[multilib]/' '$pacman_conf'
      awk '
        BEGIN { in_multilib=0 }
        /^\[multilib\]/ { in_multilib=1; print; next }
        /^\[/ && \$0 !~ /\[multilib\]/ { in_multilib=0 }
        in_multilib && /^#Include = \/etc\/pacman.d\/mirrorlist/ {
          print \"Include = /etc/pacman.d/mirrorlist\"; next
        }
        { print }
      ' '$pacman_conf' > '$pacman_conf.tmp' && mv '$pacman_conf.tmp' '$pacman_conf'
    "
  fi
}

# === Enable colored output in pacman ===
enable_color() {
  if grep -qF "Color" "$pacman_conf"; then
    success "Color output already enabled."
  else
    run_with_spinner "Enabling colored output" sudo sed -i 's/^#Color/Color/' "$pacman_conf"
  fi
}

# === Add CachyOS repo ===
add_cachyos_repo() {
  if grep -qF "[cachyos]" "$pacman_conf"; then
    success "CachyOS repo already exists."
  else
    local tmpdir
    tmpdir=$(mktemp -d)
    run_with_spinner "Downloading and adding CachyOS repo" bash -c "
      cd '$tmpdir'
      curl -sL https://mirror.cachyos.org/cachyos-repo.tar.xz -o repo.tar.xz
      tar xf repo.tar.xz
      cd cachyos-repo && sudo ./cachyos-repo.sh
    "
    rm -rf "$tmpdir"
    success "CachyOS repo added."
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
    linux-cachyos base-devel steam modrinth-app-bin protonplus okular linux-prjc linux-prjc-headers
    pfetch fastfetch kvantum dunst protonup-rs mangojuice ffmpeg volt-gui localsend-bin spotify
    ttf-jetbrains-mono-nerd inter-font github-desktop-bin inkscape bazaar kcolorchooser
    os-prober starship audacious proton-cachyos firefox kdenlive gimp krita gwenview discord
    git bottles xorg-xlsclients papirus-icon-theme plasma6-themes-chromeos-kde-git kwrited
    gamepadla-polling chromeos-gtk-theme-git konsave mangohud flatpak lmstudio proton-ge-custom-bin
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
    io.gitlab.news_flash.NewsFlash
    fr.handbrake.ghb
    org.gnome.gitlab.YaLTeR.VideoTrimmer
    com.github.unrud.VideoDownloader
    com.github.tenderowl.frog
    org.gnome.Calculator
    com.vscodium.codium
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
alias up="yay -Syu && protonup-rs -q && flatpak update"
alias update-grub="sudo grub-mkconfig -o /boot/grub/grub.cfg"
alias xwayland-list="xlsclients -l"
alias mic-volume-set="wpctl set-volume"
alias mic-volume-status="wpctl status | awk '/USB Audio Microphone/{flag=1} flag && /vol:/{print $2; exit}'"
alias polling="gamepadla-polling"
alias rl-launch="echo BAKKES=1 PROMPTLESS=1 PROTON_ENABLE_WAYLAND=1 mangohud %command%"
alias yay-recent="grep -i installed /var/log/pacman.log | tail -n 30"
alias bakkes-update="if pacman -Qs bakkesmod-steam > /dev/null; then yay -Rns bakkesmod-steam && yay -Sy bakkesmod-steam --rebuild --noconfirm; else yay -Sy bakkesmod-steam --rebuild --noconfirm; fi"
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

# === Setup mic volume script ===
setup_mic_volume_script() {
  local mic_script="$HOME/.local/bin/mic-volume-set.sh"
  mkdir -p "$(dirname "$mic_script")"

  cat > "$mic_script" <<'EOF'
#!/bin/bash
MIC_ID=$(wpctl status | awk '/USB Audio Microphone/{print $3}' | tr -d '.')
if [[ -n "$MIC_ID" ]]; then
    wpctl set-volume "$MIC_ID" 1.4
fi
EOF

  chmod +x "$mic_script"
  success "Mic volume script created at $mic_script"
}

# === Setup mic volume script ===
setup_mic_volume_script() {
  run_with_spinner "Creating mic volume script" bash -c "
    local mic_script=\"$HOME/.local/bin/mic-volume-set.sh\"
    mkdir -p \"\$(dirname \"\$mic_script\")\"

    cat > \"\$mic_script\" <<'EOF'
#!/bin/bash
MIC_ID=\$(wpctl status | awk '/USB Audio Microphone/{print \$3}' | tr -d '.')
if [[ -n \"\$MIC_ID\" ]]; then
    wpctl set-volume \"\$MIC_ID\" 1.4
fi
EOF

    chmod +x \"\$mic_script\"
  "
  success "Mic volume script created at $HOME/.local/bin/mic-volume-set.sh"
}

# === Setup mic volume script ===
setup_mic_volume_script() {
  local mic_script="$HOME/.local/bin/mic-volume-set.sh"

  run_with_spinner "Creating mic volume script" bash -c "
    mkdir -p \"$(dirname "$mic_script")\"

    cat > \"$mic_script\" <<'EOF'
#!/bin/bash
MIC_ID=\$(wpctl status | awk '/USB Audio Microphone/{print \$3}' | tr -d '.')
if [[ -n \"\$MIC_ID\" ]]; then
    wpctl set-volume \"\$MIC_ID\" 1.4
fi
EOF

    chmod +x \"$mic_script\"
  "
  success "Mic volume script created at $mic_script"
}

# === Setup systemd service for mic volume ===
setup_mic_systemd_service() {
  local service_dir="$HOME/.config/systemd/user"
  local service_file="$service_dir/mic-volume.service"

  run_with_spinner "Creating mic volume systemd service" bash -c "
    mkdir -p \"$service_dir\"

    cat > \"$service_file\" <<EOF
[Unit]
Description=Set USB Mic Volume on Login
After=graphical.target

[Service]
Type=oneshot
ExecStart=$HOME/.local/bin/mic-volume-set.sh

[Install]
WantedBy=default.target
EOF
  "
  systemctl --user daemon-reload
  systemctl --user enable mic-volume.service
  success "Mic volume systemd service created and enabled"
}

# === Main ===
main() {
  enable_multilib
  enable_color
  add_cachyos_repo
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
  setup_mic_volume_script
  setup_mic_systemd_service
  echo -e "\n${GREEN}All done! Reboot is recommended.${RESET}"
}
main
