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

# Install tools via pacman
if [ "$SYMLINKS_ONLY" = false ]; then
  echo "Installing tools via pacman..."
  sudo pacman -S --needed --noconfirm difftastic fzf neovim vim tmux wezterm
fi

# Create symlinks for configuration files
echo "Creating symlinks..."

create_symlink() {
  local target="$1"
  local link="$2"

  # Create parent directory if needed
  mkdir -p "$(dirname "$link")"

  # Back up existing file (not symlink) before replacing
  if [ -e "$link" ] && [ ! -L "$link" ]; then
    echo "Backing up existing file: $link -> ${link}.bak"
    mv "$link" "${link}.bak"
  fi

  # Remove existing symlink
  if [ -L "$link" ]; then
    rm -f "$link"
  fi

  ln -s "$target" "$link"
  echo "Created symlink: $link -> $target"
}

create_symlink "$SCRIPT_DIR/vim/vimrc" "$HOME/.vimrc"
create_symlink "$SCRIPT_DIR/tmux/tmux.conf" "$HOME/.tmux.conf"
create_symlink "$SCRIPT_DIR/wezterm/wezterm.lua" "$HOME/.config/wezterm/wezterm.lua"
create_symlink "$SCRIPT_DIR/nvim" "$HOME/.config/nvim"
create_symlink "$SCRIPT_DIR/ohmyzsh/zshrc" "$HOME/.zshrc"
create_symlink "$SCRIPT_DIR/ohmyzsh/zshenv" "$HOME/.zshenv"

echo "Done!"
