#!/usr/bin/env bash
set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[DONE]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   error "This script must not be run as root"
fi

log "Starting minimal Hyprland setup..."

# Configure pacman
log "Configuring pacman..."
sudo sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 10/' /etc/pacman.conf
sudo sed -i 's/#Color/Color/' /etc/pacman.conf

# Enable multilib (needed for some 32-bit NVIDIA libs)
sudo sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf

# Update system
log "Updating system..."
sudo pacman -Syu --noconfirm

# Essential packages only
PKGS=(
    # Base essentials
    base-devel
    git
    
    # For NVIDIA DKMS
    linux-headers
    
    # NVIDIA drivers (open source kernel modules)
    nvidia-open-dkms
    nvidia-utils
    lib32-nvidia-utils
    nvidia-settings
    
    # Hyprland core
    hyprland
    kitty
    waybar
    wofi
    dunst
    
    # Wayland essentials
    xdg-desktop-portal-hyprland
    qt5-wayland
    qt6-wayland
    
    # NVIDIA Wayland support
    egl-wayland
    
    # Hardware video acceleration
    libva-nvidia-driver
    
    # Vulkan support
    vulkan-icd-loader
    lib32-vulkan-icd-loader
    vulkan-tools
    
    # Audio
    pipewire
    pipewire-pulse
    wireplumber
    
    # Essential utilities
    hyprpolkitagent
    grim
    slurp
    wl-clipboard
    xdg-utils
    
    # Network
    networkmanager
    network-manager-applet
    
    # File manager
    thunar
    
    # Shell
    zsh
    
    # Fonts (minimal)
    ttf-jetbrains-mono-nerd
    noto-fonts
    noto-fonts-emoji
    
    # Performance
    cpupower
    
    # Gaming/Performance optimization
    gamemode
    lib32-gamemode
    mangohud
    lib32-mangohud
    nvtop
)

log "Installing packages..."
sudo pacman -S --needed --noconfirm "${PKGS[@]}"

# Install yay
if ! command -v yay &> /dev/null; then
    log "Installing yay..."
    cd /tmp
    git clone https://aur.archlinux.org/yay-bin.git
    cd yay-bin
    makepkg -si --noconfirm
    cd ~
    rm -rf /tmp/yay-bin
fi

# Install Google Chrome from AUR
log "Installing Google Chrome..."
yay -S --needed --noconfirm google-chrome

# Install performance tools from AUR
log "Installing performance optimization tools..."
yay -S --needed --noconfirm corectrl zenpower3-dkms zenstates-git

# Enable services
log "Enabling services..."
sudo systemctl enable NetworkManager
sudo systemctl enable cpupower

# NVIDIA configuration following Hyprland wiki
log "Configuring NVIDIA..."

# Create modprobe config for DRM modeset
sudo tee /etc/modprobe.d/nvidia.conf << 'EOF'
options nvidia_drm modeset=1
EOF

# Add NVIDIA modules to initramfs for early KMS
sudo sed -i 's/^MODULES=(/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm /' /etc/mkinitcpio.conf

# Rebuild initramfs
log "Rebuilding initramfs..."
sudo mkinitcpio -P

# Set CPU to performance
log "Setting CPU to performance mode..."
sudo cpupower frequency-set -g performance

# Create cpupower config
echo "governor='performance'" | sudo tee /etc/default/cpupower

# Set Zsh as default shell
if [[ "$SHELL" != "/bin/zsh" ]]; then
    log "Setting zsh as default shell..."
    chsh -s /bin/zsh
fi

# Create config directories
mkdir -p ~/.config/hypr

# Git setup
log "Setting up git..."
read -p "Enter your git username: " git_user
read -p "Enter your git email: " git_email
git config --global user.name "$git_user"
git config --global user.email "$git_email"
git config --global init.defaultBranch main

# Create NVIDIA setup instructions
cat << 'EOF' > ~/nvidia-hyprland-setup.txt
NVIDIA Hyprland Setup Instructions
==================================

1. Verify DRM is enabled:
   cat /sys/module/nvidia_drm/parameters/modeset
   Should return: Y

2. Add to your Hyprland config (~/.config/hypr/hyprland.conf):

   # NVIDIA environment variables
   env = LIBVA_DRIVER_NAME,nvidia
   env = __GLX_VENDOR_LIBRARY_NAME,nvidia
   env = NVD_BACKEND,direct
   
   # Electron apps native Wayland
   env = ELECTRON_OZONE_PLATFORM_HINT,auto
   env = NIXOS_OZONE_WL,1

3. Multi-monitor setup (2560x1440@240Hz primary + vertical 2560x1440@75Hz):
   
   # Monitor configuration
   # monitor=name,resolution@rate,position,scale,transform
   monitor=DP-1,2560x1440@240,0x0,1
   monitor=DP-2,2560x1440@75,2560x0,1,transform,3
   
   # Transform values: 0 normal, 1 = 90°, 2 = 180°, 3 = 270° (bottom facing right)
   
   # To identify monitor names, run:
   hyprctl monitors
   
   # Alternative: use 'highres' for auto-detection
   monitor=DP-1,highres,0x0,1
   monitor=DP-2,highres,2560x0,1,transform,3

4. For Electron app flickering, launch with:
   --enable-features=UseOzonePlatform,WaylandLinuxDrmSyncobj --ozone-platform=wayland

5. Check VA-API is working:
   vainfo

6. Check Vulkan is working:
   vulkaninfo --summary
   vkcube  # Should show a spinning cube

7. To use gamemode, add to game launch options:
   gamemoderun %command%

8. Monitor GPU performance:
   nvtop

9. Configure GPU/CPU profiles:
   corectrl

10. Check AMD CPU states:
    zenstates --list

Common Window Rules (Add to ~/.config/hypr/hyprland.conf):
============================================================

# 1Password - Float and center
windowrulev2 = float, title:(1Password)
windowrulev2 = size 70% 70%, title:(1Password)
windowrulev2 = center, title:(1Password)

# Godot - Fix dialogs and popups
windowrulev2 = float, class:(Godot)
windowrulev2 = windowdance, class:(Godot)
windowrulev2 = center, class:(Godot), floating:1

# Steam - Fix dropdown menus and friends list
windowrulev2 = stayfocused, title:^()$,class:^(steam)$
windowrulev2 = minsize 1 1, title:^()$,class:^(steam)$
windowrulev2 = nofocus, class:^(steam)$, title:^(notificationtoasts)$
# Add to input section for Steam menus:
# mouse_refocus = false

# Discord - Auto to workspace
windowrulev2 = workspace 9, class:^(discord)$

# File pickers and save dialogs
windowrulev2 = float, title:^(Open File)$
windowrulev2 = float, title:^(Save As)$
windowrulev2 = float, title:^(Save File)$
windowrulev2 = float, title:^(Open Folder)$
windowrulev2 = size 80% 80%, title:^(Open File)$
windowrulev2 = center, title:^(Open File)$

# Firefox Picture-in-Picture
windowrulev2 = float, title:^(Picture-in-Picture)$
windowrulev2 = pin, title:^(Picture-in-Picture)$
windowrulev2 = size 25% 25%, title:^(Picture-in-Picture)$
windowrulev2 = move 72% 7%, title:^(Picture-in-Picture)$

# Pavucontrol and system settings
windowrulev2 = float, class:^(pavucontrol)$
windowrulev2 = size 60% 60%, class:^(pavucontrol)$
windowrulev2 = center, class:^(pavucontrol)$

# Authentication dialogs
windowrulev2 = float, class:^(hyprpolkitagent)$
windowrulev2 = center, class:^(hyprpolkitagent)$

# VS Code
windowrulev2 = tile, class:^(Code)$
windowrulev2 = float, class:^(Code), title:^(Open File)$
windowrulev2 = float, class:^(Code), title:^(Open Folder)$

# Gaming optimizations
windowrulev2 = immediate, class:^(cs2)$  # Disable composition
windowrulev2 = tearinghint:on, class:^(cs2)$  # Allow tearing

# General popup fixes
windowrulev2 = float, title:^(Confirm)(.*)$
windowrulev2 = float, title:^(Dialog)(.*)$
windowrulev2 = float, title:^(dialog)(.*)$
windowrulev2 = float, title:^(Preferences)(.*)$
windowrulev2 = float, title:^(About)(.*)$

# XWayland drag fix
windowrulev2 = nofocus,class:^$,title:^$,xwayland:1,floating:1,fullscreen:0,pinned:0

Tips for Finding Window Info:
-----------------------------
- Run: hyprctl clients
- Look for "class:" and "title:" fields
- Use: hyprctl activewindow for current window
- For dynamic titles, use regex: title:^(Start)(.*)$

Useful Keybinds to Add:
-----------------------
# Clipboard history (SUPER+V)
bind = SUPER, V, exec, cliphist list | wofi --dmenu | cliphist decode | wl-copy

# Clear clipboard history
bind = SUPER SHIFT, V, exec, cliphist wipe

Additional Tips:
----------------
- Force VRR/G-Sync: Add to monitor line ,vrr,1
- 10-bit color: Add ,bitdepth,10 to monitor config
- Disable monitor: monitor=DP-2,disable
- Mirror displays: Use same position for both monitors
- Custom workspaces per monitor:
  workspace=1,monitor:DP-1
  workspace=2,monitor:DP-2

Performance Tips:
-----------------
- Disable composition on fullscreen for better FPS:
  windowrulev2 = immediate, class:^(cs2)$
  
- Force tearing for specific games (reduces latency):
  windowrulev2 = immediate, class:^(cs2)$
  windowrulev2 = tearinghint, class:^(cs2)$

- Use CoreCtrl to overclock GPU and set fan curves
- Disable boost on 5800X3D if temps are high:
  sudo zenstates --disable-boost

Notes:
------
- NVIDIA suspend/resume services are enabled by default on Arch
- Use MangoHud overlay in games with Shift+F12
- If monitor isn't detected at correct refresh rate, may need custom EDID
- WLR_DRM_NO_ATOMIC=1 can help with some monitor issues
EOF

success "Minimal setup complete!"
echo ""
echo "Next steps:"
echo "1. Reboot your system"
echo "2. Check ~/nvidia-hyprland-setup.txt for NVIDIA configuration"
echo "3. Add the environment variables to your Hyprland config"
echo "4. Run 'Hyprland' to start"