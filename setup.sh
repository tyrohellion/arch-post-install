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
  protonup-qt linux-cachyos base-devel steam \
  pfetch fastfetch kvantum discord cider dunst micro \
  ttf-jetbrains-mono-nerd inter-font code vlc github-desktop-bin \
  os-prober starship audacious \
  firefox kdenlive gimp krita inkscape git bottles \
  papirus-icon-theme plasma6-themes-chromeos-kde-git \
  chromeos-gtk-theme-git konsave mangohud flatpak || {
    echo "Some packages failed to install"; exit 2;
}

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

sudo grub-mkconfig -o /boot/grub/grub.cfg

echo "=== Customizing .bashrc ==="
alias_up='alias up="yay -Syu && flatpak update"'
alias_update_grub='alias update-grub="sudo grub-mkconfig -o /boot/grub/grub.cfg"'
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

add_env_var "MOZ_ENABLE_WAYLAND" "1"
add_env_var "MANGOHUD" "1"
add_env_var "MANGOHUD_CONFIG" "cellpadding_y=0.1, wine, font_size=20, no_display, winesync, display_server, vsync=1, gl_vsync=0"
add_env_var "ELECTRON_OZONE_PLATFORM_HINT" "auto"

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
