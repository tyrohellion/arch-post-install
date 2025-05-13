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
4. Installs yay alongside all packages I use
5. Applies my personal konsave profile
6. Enables os-prober for dual booting with my Windows drive
7. Adds my .bashrc configs and configures starship
8. Adds my personal env variables to /etc/environment
9. Fetches and applies my own firefox theme and user.js
10. Installs grub theme (https://github.com/vinceliuice/Elegant-grub2-themes)
