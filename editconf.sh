#!/usr/bin/env bash

# Quick config opener for your setup
# Usage: ./configs.sh or add to PATH as 'configs'

# Your config files and directories
declare -a CONFIGS=(
    "$HOME/.config/nvim"
    "$HOME/.config/kitty/kitty.conf"
    "$HOME/.config/hypr/hyprland.conf"
    "$HOME/.config/tmux/tmux.conf"
    "$HOME/.config/zsh/.zshrc"
    "$HOME/.config/waybar/config"
    "$HOME/.config/waybar/style.css"
    "$HOME/.zshrc"
    "$HOME/.tmux.conf"
    "$HOME/.gitconfig"
    "$HOME/.ssh/config"
)

# Check dependencies
if ! command -v fzf >/dev/null 2>&1; then
    echo "Error: fzf is required" >&2
    exit 1
fi

if ! command -v nvim >/dev/null 2>&1; then
    echo "Error: neovim is required" >&2
    exit 1
fi

# Preview command
preview_cmd='
if [[ -d {} ]]; then
    if command -v eza >/dev/null 2>&1; then
        eza -la --color=always --group-directories-first {}
    else
        ls -la --color=always {}
    fi
elif [[ -f {} ]]; then
    if command -v bat >/dev/null 2>&1; then
        bat --color=always --style=header,grid --line-range=:50 {}
    else
        head -50 {}
    fi
else
    echo "File does not exist yet: {}"
fi'

# Use fzf to select and open
selected=$(printf '%s\n' "${CONFIGS[@]}" | fzf \
    --height=60% \
    --layout=reverse \
    --border \
    --preview="$preview_cmd" \
    --preview-window="right:50%" \
    --header="Select config to open in Neovim" \
    --prompt="Config> ")

if [[ -n "$selected" ]]; then
    # Create directory if it doesn't exist
    mkdir -p "$(dirname "$selected")"
    nvim "$selected"
fi
