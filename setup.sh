#!/bin/bash

set -e

pacman_conf="/etc/pacman.conf"
grub_conf="/etc/default/grub"
bashrc_file="$HOME/.bashrc"

echo "=== Enabling multilib ==="
if grep -q "^\[multilib\]" "$pacman_conf"; then
  echo "Multilib is already enabled."
else
  sudo sed -i 's/^#\[multilib\]/[multilib]/' "$pacman_conf"
  sudo awk '
    BEGIN { in_multilib=0 }
    /^\[multilib\]/ { in_multilib=1; print; next }
    /^\[/ && $0 !~ /\[multilib\]/ { in_multilib=0 }
    in_multilib && /^#Include = \/etc\/pacman.d\/mirrorlist/ {
      print "Include = /etc/pacman.d/mirrorlist"; next
    }
    { print }
  ' "$pacman_conf" | sudo tee "$pacman_conf.tmp" > /dev/null && sudo mv "$pacman_conf.tmp" "$pacman_conf"
  echo "Multilib enabled."
fi

echo "=== Enabling colored output ==="
if grep -q "^Color" "$pacman_conf"; then
  echo "Color is already enabled."
else
  sudo sed -i 's/^#Color/Color/' "$pacman_conf" && echo "Color output enabled."
fi

echo "=== Adding CachyOS repo ==="
if ! grep -q "\[cachyos\]" "$pacman_conf"; then
  curl https://mirror.cachyos.org/cachyos-repo.tar.xz -o cachyos-repo.tar.xz
  tar xvf cachyos-repo.tar.xz && cd cachyos-repo
  sudo ./cachyos-repo.sh
  cd ..
  echo "CachyOS repo added."
else
  echo "CachyOS repo already exists in pacman.conf."
fi


echo "=== Adding Cider Collective repo ==="
if ! grep -q "\[cidercollective\]" "$pacman_conf"; then
  if ! pacman-key --list-keys | grep -q "A0CD6B993438E22634450CDD2A236C3F42A61682"; then
    curl -s https://repo.cider.sh/ARCH-GPG-KEY | sudo pacman-key --add -
    sudo pacman-key --lsign-key A0CD6B993438E22634450CDD2A236C3F42A61682
  else
    echo "Cider GPG key already added."
  fi
  sudo tee -a "$pacman_conf" << 'EOF'
  
# Cider Collective Repository
[cidercollective]
SigLevel = Required TrustedOnly
Server = https://repo.cider.sh/arch
EOF
  echo "Cider Collective repo added."
else
  echo "Cider Collective repo already exists in pacman.conf."
fi

echo "=== Installing yay ==="
sudo pacman -Sy --noconfirm yay || { echo "Failed to install yay"; exit 1; }

echo "=== Installing packages ==="
yay -Syu --needed --noconfirm \
  linux-cachyos base-devel steam modrinth-app-bin stremio-linux-shell-git \
  pfetch fastfetch kvantum discord dunst micro protonup-rs \
  ttf-jetbrains-mono-nerd inter-font code vlc github-desktop-bin \
  os-prober starship audacious proton-cachyos stremio-linux-shell-git \
  firefox kdenlive gimp krita inkscape git bottles xorg-xlsclients \
  papirus-icon-theme plasma6-themes-chromeos-kde-git gamepadla-polling \
  chromeos-gtk-theme-git konsave mangohud flatpak cidercollective/cider || {
    echo "Some packages failed to install"; exit 2;
}

echo "=== Please install proton-ge ==="
protonup-rs

echo "=== Applying konsave profile ==="
knsv_file="arch.knsv"

if [[ -f "$knsv_file" ]]; then
  konsave -i "$knsv_file"
  konsave -a arch
  echo "Konsave profile 'arch' imported and applied."
else
  echo "Konsave file '$knsv_file' not found in current directory. Skipping konsave apply."
fi

echo "=== Enabling OS prober for GRUB ==="
if grep -q "^#GRUB_DISABLE_OS_PROBER=false" "$grub_conf"; then
  sudo sed -i 's/^#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' "$grub_conf"
  echo "GRUB_DISABLE_OS_PROBER enabled."
else
  echo "GRUB_DISABLE_OS_PROBER already enabled or manually set."
fi

echo "=== Setting GRUB_CMDLINE_LINUX_DEFAULT ==="
desired_cmdline="GRUB_CMDLINE_LINUX_DEFAULT='nowatchdog nvme_load=YES zswap.enabled=0 loglevel=3 usbhid.jspoll=1 xpad.cpoll=1'"

if grep -q "^GRUB_CMDLINE_LINUX_DEFAULT=" "$grub_conf"; then
  sudo sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=.*/$desired_cmdline/" "$grub_conf"
  echo "Updated GRUB_CMDLINE_LINUX_DEFAULT."
else
  echo "$desired_cmdline" | sudo tee -a "$grub_conf" > /dev/null
  echo "Added GRUB_CMDLINE_LINUX_DEFAULT to $grub_conf."
fi

sudo grub-mkconfig -o /boot/grub/grub.cfg

echo "=== Customizing .bashrc ==="
alias_up='alias up="yay -Syu && protonup-rs -q && flatpak update"'
alias_update_grub='alias update-grub="sudo grub-mkconfig -o /boot/grub/grub.cfg"'
alias_xwayland_list='alias xwayland-list="xlsclients -l"'
alias_polling_rate='alias polling="gamepadla-polling"'
alias_rl_launch='alias rl-launch="echo BAKKES=1 PROMPTLESS=1 PROTON_ENABLE_WAYLAND=1 WAYLANDDRV_PRIMARY_MONITOR=DP-1 %command%"'
alias_bakkesmod_refresh='alias bakkes-update="
if pacman -Qs bakkesmod-steam > /dev/null; then
  yay -Rns bakkesmod-steam && yay -S bakkesmod-steam --rebuild --noconfirm
else
  yay -S bakkesmod-steam --rebuild --noconfirm
fi
"'
starship_init='eval "$(starship init bash)"'
pfetch_cmd="pfetch"

if ! grep -Fxq "$pfetch_cmd" "$bashrc_file"; then
  sed -i "1s|^|$pfetch_cmd\n|" "$bashrc_file"
  echo "Added at top: $pfetch_cmd"
else
  echo "Already exists at top: $pfetch_cmd"
fi

add_line() {
  local line="$1"
  if ! grep -Fxq "$line" "$bashrc_file"; then
    echo "$line" >> "$bashrc_file"
    echo "Added: $line"
  else
    echo "Already exists: $line"
  fi
}

add_line "$alias_up"
add_line "$alias_update_grub"
add_line "$alias_xwayland_list"
add_line "$alias_polling_rate"
add_line "$alias_rl_launch"
add_line "$alias_bakkesmod_refresh"
add_line "$starship_init"

echo "=== Adding environment variables to /etc/environment ==="

env_file="/etc/environment"

add_env_var() {
  local key="$1"
  local value="$2"
  if grep -q "^${key}=" "$env_file"; then
    echo "$key already set in /etc/environment."
  else
    echo "$key=\"$value\"" | sudo tee -a "$env_file" > /dev/null
    echo "Added: $key=\"$value\""
  fi
}

add_env_var "MANGOHUD" "1"
add_env_var "MANGOHUD_CONFIG" "cellpadding_y=0.1, wine, font_size=20, no_display, winesync, display_server, vsync=1, gl_vsync=0"
add_env_var "ELECTRON_OZONE_PLATFORM_HINT" "auto"
add_env_var "VKD3D_FRAME_RATE" "237"
add_env_var "DXVK_FRAME_RATE" "237"

echo "=== Applying Firefox customizations ==="

git clone https://github.com/tyrohellion/arcadia
cd arcadia

firefox_dir="$HOME/.mozilla/firefox"
profile_path=$(find "$firefox_dir" -maxdepth 1 -type d -name "*default-release" | head -n 1)

if [[ -d "$profile_path" ]]; then
  echo "Firefox profile found: $profile_path"

  cp -r chrome "$profile_path/"
  cp user.js "$profile_path/"
  echo "Custom Firefox files copied to profile."
else
  echo "Firefox default-release profile not found. Skipping customization."
fi

cd ..
rm -rf arcadia

echo "=== Installing Elegant GRUB theme ==="
git clone https://github.com/vinceliuice/Elegant-grub2-themes
cd Elegant-grub2-themes
sudo ./install.sh -t forest -p float -i left -c dark -s 1080p -l system
cd ..
rm -rf Elegant-grub2-themes
echo "Elegant GRUB theme installed and folder removed."

echo "=== All done. Reboot recommended. ==="
