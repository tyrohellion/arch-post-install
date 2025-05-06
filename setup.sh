pacman="/etc/pacman.conf"

sudo sed -i 's/^#\[multilib\]/[multilib]/' "$pacman"

sudo awk '
  BEGIN { in_multilib=0 }
  /^\[multilib\]/ { in_multilib=1; print; next }
  /^\[/ && $0 !~ /\[multilib\]/ { in_multilib=0 }
  in_multilib && /^#Include = \/etc\/pacman.d\/mirrorlist/ {
    print "Include = /etc/pacman.d/mirrorlist"; next
  }
  { print }
' "$pacman" | sudo tee "$pacman.tmp" > /dev/null && sudo mv "$pacman.tmp" "$pacman"

sudo sed -i 's/^#Color/Color/' "$pacman"

echo "Multilib and color support have been enabled"

curl https://mirror.cachyos.org/cachyos-repo.tar.xz -o cachyos-repo.tar.xz
tar xvf cachyos-repo.tar.xz && cd cachyos-repo
sudo ./cachyos-repo.sh
cd ..

yay -Syu proton-cachyos linux-cachyos base-devel yay steam pfetch fastfetch equibop kvantum proton-ge-custom-bin os-prober starship firefox kdenlive gimp krita inkscape papirus-icon-theme plasma6-themes-chromeos-kde-git chromeos-gtk-theme-git konsave mangohud flatpak

grub="/etc/default/grub"

sudo sed -i 's/^#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER=false/' "$grub"

echo "GRUB_DISABLE_OS_PROBER has been enabled in /etc/default/grub"

sudo grub-mkconfig -o /boot/grub/grub.cfg

bashrc_file="$HOME/.bashrc"

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

git clone https://github.com/vinceliuice/Elegant-grub2-themes
cd Elegant-grub2-themes
sudo ./install.sh
