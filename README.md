## Installation

1. `git clone https://github.com/tyrohellion/distro-post-install`
2. `cd distro-post-install`
3. `cd <Arch or Solus>`
4. `sudo chmod +x ./setup.sh`
5. `./setup.sh`

## Why?

To automate my personal Arch Linux or Solus install whenever I need to

## Summary of changes

1. Enables multilib and Color in /etc/pacman.conf
4. Handles all packages, Flatpak and System
5. Applies my personal konsave profile
6. Enables os-prober and kernel parameters
7. Applies my .bashrc configs and configures starship
8. Applies my personal env variables to /etc/environment
9. Applies my mangohud config file
10. Applies my Alacritty config
11. Fetches and applies my own firefox theme and user.js
12. Installs grub theme (https://github.com/vinceliuice/Elegant-grub2-themes)
