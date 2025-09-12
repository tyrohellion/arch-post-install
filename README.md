## Installation

1. `git clone https://github.com/tyrohellion/arch-post-install`
2. `cd arch-post-install`
3. `chmod +x setup.sh`
4. `./setup.sh`

## Why?

To automate my personal Arch Linux install whenever I need to

## Summary of changes

1. Enables multilib and Color in /etc/pacman.conf
2. Adds the CachyOS repositories
3. Adds the Cider Collective repository
4. Installs yay and flatpak packages
5. Applies my personal konsave profile
6. Enables os-prober and kernel parameters
7. Applies my .bashrc configs and configures starship
8. Applies my personal env variables to /etc/environment
9. Applies my mangohud config file
10. Fetches and applies my own firefox theme and user.js
11. Installs grub theme (https://github.com/vinceliuice/Elegant-grub2-themes)
