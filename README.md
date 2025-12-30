# configs
Configuration I cannot live without

## Contents

- `tmux/tmux.conf` - tmux configuration
- `vim/vimrc` - Vim configuration
- `wezterm/wezterm.lua` - WezTerm terminal configuration
- `ohmyzsh/zshrc` - Zsh configuration (with modular config in `ohmyzsh/modules/`)
- `install_windows.sh` - Install tools via Chocolatey and create symlinks

## Installation

```bash
# Install tools and create symlinks
./install_windows.sh

# Create symlinks only (skip Chocolatey)
./install_windows.sh --symlinks-only
```
