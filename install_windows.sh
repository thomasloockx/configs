#!/usr/bin/env bash

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
  powershell -Command "Start-Process powershell -Verb RunAs -Wait -ArgumentList '-Command choco install difftastic fzf neovim vim wezterm jetbrainsmono --yes'"
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

  # Try native Windows symlinks first (requires Developer Mode or admin)
  MSYS=winsymlinks:nativestrict ln -s "$target" "$link" 2>/dev/null
  if [ $? -eq 0 ]; then
    echo "Created symlink: $link -> $target"
    return 0
  fi

  # Fallback to hardlink (works without admin, but only for files on same drive)
  ln "$target" "$link" 2>/dev/null
  if [ $? -eq 0 ]; then
    echo "Created hardlink: $link -> $target"
    return 0
  fi

  echo "ERROR: Failed to create link. Enable Developer Mode for symlinks:"
  echo "  Windows Settings > Privacy & Security > For developers > Developer Mode"
  return 1
}

create_symlink "$SCRIPT_DIR/vim/vimrc" "$HOME/.vimrc"
create_symlink "$SCRIPT_DIR/tmux/tmux.conf" "$HOME/.tmux.conf"
create_symlink "$SCRIPT_DIR/wezterm/wezterm.lua" "$HOME/.wezterm.lua"
# Also create in .config/wezterm/ where WezTerm looks on Windows
mkdir -p "$HOME/.config/wezterm"
create_symlink "$SCRIPT_DIR/wezterm/wezterm.lua" "$HOME/.config/wezterm/wezterm.lua"
create_symlink "$SCRIPT_DIR/ohmyzsh/zshrc" "$HOME/.zshrc"
create_symlink "$SCRIPT_DIR/ohmyzsh/rayscaper_dev.zsh" "$HOME/.rayscaper_dev.zsh"

mkdir -p "$HOME/AppData/Roaming/Code/User"
WIN_VSCODE_SETTINGS="$(cygpath -w "$SCRIPT_DIR/vscode/settings.json")"
powershell -Command "New-Item -ItemType HardLink -Path '$env:USERPROFILE\AppData\Roaming\Code\User\settings.json' -Target '$WIN_VSCODE_SETTINGS' -Force"

# Install VS Code extensions
if [ "$SYMLINKS_ONLY" = false ] && command -v code &>/dev/null; then
  echo "Installing VS Code extensions..."
  while IFS= read -r ext; do
    code --install-extension "$ext" --force 2>/dev/null
  done <"$SCRIPT_DIR/vscode/extensions.txt"
fi

echo "Done!"
