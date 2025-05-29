#!/usr/bin/env bash
set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[DONE]${NC} $1"; }

log "Starting post-install setup..."

# System update
log "Updating system..."
sudo pacman -Syu --noconfirm

# Core packages
PKGS=(
    # Hyprland essentials
    hyprland waybar dunst kitty hyprpaper
    xdg-desktop-portal-hyprland
    
    # Audio
    pipewire pipewire-pulse wireplumber pavucontrol
    
    # System utilities
    xdg-utils hyprpolkitagent
    nemo google-chrome firefox
    
    # Screenshots/clipboard
    grim slurp wl-clipboard cliphist
    
    # Development
    git neovim base-devel
    eza bat fzf ripgrep fd
    
    # System performance
    cpupower
    
    # Shell
    zsh
    
    # Fonts
    ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols
    noto-fonts noto-fonts-emoji
    
    # Theme
    adw-gtk-theme
    
    # NVIDIA packages
    nvidia-open-dkms nvidia-utils linux-zen-headers
    qt5-wayland qt6-wayland egl-wayland
)

# Configure pacman for speed and convenience
log "Configuring pacman..."
sudo sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 10/' /etc/pacman.conf
sudo sed -i 's/#Color/Color/' /etc/pacman.conf
sudo sed -i 's/#VerbosePkgLists/VerbosePkgLists/' /etc/pacman.conf

log "Installing packages..."
sudo pacman -S --needed --noconfirm "${PKGS[@]}"

# Install yay
if ! command -v yay &> /dev/null; then
    log "Installing yay..."
    cd /tmp
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd ~
    rm -rf /tmp/yay
    success "yay installed"
    
    # Configure yay for convenience
    log "Configuring yay..."
    yay --save --answerclean All --answerdiff None --answeredit None --answerupgrade None
fi

# Set default shell to zsh
if [[ "$SHELL" != "/bin/zsh" ]]; then
    log "Setting zsh as default shell..."
    chsh -s /bin/zsh
    success "Shell changed to zsh (logout/login required)"
fi

# Git setup
log "Setting up git..."
read -p "Enter your git username: " git_user
read -p "Enter your git email: " git_email
git config --global user.name "$git_user"
git config --global user.email "$git_email"
git config --global init.defaultBranch trunk
success "Git configured"

# Setup Mise
log "Installing and setting up Mise..."
curl https://mise.run | sh
echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc
echo 'eval "$(~/.local/bin/mise activate zsh)"' >> ~/.zshrc
success "Mise installed and configured"

# Set CPU to performance mode
log "Setting CPU to performance mode..."
sudo cpupower frequency-set -g performance
sudo systemctl enable cpupower.service
success "CPU set to performance mode"

# Copy config files if they exist
log "Setting up config files..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -d "$SCRIPT_DIR/configs/hypr" ]]; then
    mkdir -p ~/.config/hypr
    cp -r "$SCRIPT_DIR/configs/hypr/"* ~/.config/hypr/
    success "Hyprland config copied"
else
    log "No Hyprland config found, skipping..."
fi

if [[ -d "$SCRIPT_DIR/configs/kitty" ]]; then
    mkdir -p ~/.config/kitty
    cp -r "$SCRIPT_DIR/configs/kitty/"* ~/.config/kitty/
    success "Kitty config copied"
else
    log "No Kitty config found, skipping..."
fi

if [[ -f "$SCRIPT_DIR/configs/.zshrc" ]]; then
    cp "$SCRIPT_DIR/configs/.zshrc" ~/
    success "Zsh config copied"
else
    log "No .zshrc found, skipping..."
fi

success "Setup complete!"
