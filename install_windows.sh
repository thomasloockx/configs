#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYMLINKS_ONLY=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --symlinks-only)
            SYMLINKS_ONLY=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--symlinks-only]"
            exit 1
            ;;
    esac
done

# Install tools via Chocolatey in elevated PowerShell
if [ "$SYMLINKS_ONLY" = false ]; then
    echo "Installing tools via Chocolatey (requires admin)..."
    powershell -Command "Start-Process powershell -Verb RunAs -Wait -ArgumentList '-Command choco install vim tmux wezterm -y'"
fi

# Download standalone tools to ~/bin
echo "Downloading standalone tools..."
mkdir -p "$HOME/bin"

if [ ! -f "$HOME/bin/viu.exe" ]; then
    echo "Downloading viu..."
    curl -L -o "$HOME/bin/viu.exe" "https://github.com/atanunq/viu/releases/download/v1.6.1/viu-x86_64-pc-windows-msvc.exe"
else
    echo "viu.exe already exists, skipping download"
fi

# Create symlinks for configuration files
echo "Creating symlinks..."

create_symlink() {
    local target="$1"
    local link="$2"

    # Remove existing file or symlink
    if [ -e "$link" ] || [ -L "$link" ]; then
        rm -f "$link"
    fi

    ln -s "$target" "$link"
    echo "Created symlink: $link -> $target"
}

create_symlink "$SCRIPT_DIR/vim/vimrc" "$HOME/.vimrc"
create_symlink "$SCRIPT_DIR/tmux/tmux.conf" "$HOME/.tmux.conf"
create_symlink "$SCRIPT_DIR/wezterm/wezterm.lua" "$HOME/.wezterm.lua"
create_symlink "$SCRIPT_DIR/ohmyzsh/zshrc" "$HOME/.zshrc"
create_symlink "$SCRIPT_DIR/ohmyzsh/rayscaper_dev.zsh" "$HOME/.rayscaper_dev.zsh"

echo "Done!"
