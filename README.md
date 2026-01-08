# configs
Configuration I cannot live without

## Contents

- `tmux/tmux.conf` - tmux configuration
- `vim/vimrc` - Vim configuration
- `nvim/` - Neovim configuration (lazy.nvim based)
- `wezterm/wezterm.lua` - WezTerm terminal configuration
- `ohmyzsh/zshrc` - Zsh configuration (with modular config in `ohmyzsh/modules/`)
- `install_windows.sh` - Install tools via Chocolatey and create symlinks

## Neovim Configuration

Modern Neovim setup using [lazy.nvim](https://github.com/folke/lazy.nvim) as plugin manager.

### Plugins

| Plugin | Description |
|--------|-------------|
| catppuccin | Colorscheme |
| telescope.nvim | Fuzzy finder |
| nvim-treesitter | Syntax highlighting |
| neo-tree.nvim | File explorer sidebar |
| which-key.nvim | Keybinding popup |
| lazygit.nvim | Git integration |
| mason.nvim | LSP server installer |
| nvim-lspconfig | LSP configuration |

### LSP Support

Pre-configured for:
- Python (pyright)
- C/C++ (clangd)
- TypeScript/JavaScript (ts_ls)

### Keybindings

**General:**
| Key | Action |
|-----|--------|
| `<Space>` | Leader key |
| `<leader>e` | Toggle file explorer |
| `<leader>E` | Reveal current file in explorer |
| `<leader>?` | Buffer local keymaps |

**Find (Telescope):**
| Key | Action |
|-----|--------|
| `<leader>ff` | Find files |
| `<leader>fg` | Live grep |
| `<leader>fb` | Buffers |
| `<leader>fh` | Help tags |
| `<leader>fr` | Recent files |
| `<leader>fp` | Git files |
| `<leader>fd` | Diagnostics |

**Git:**
| Key | Action |
|-----|--------|
| `<leader>gg` | Open LazyGit |
| `<leader>gf` | LazyGit current file |

**Code (LSP):**
| Key | Action |
|-----|--------|
| `gd` | Go to definition |
| `gD` | Go to declaration |
| `gr` | Find references |
| `gi` | Go to implementation |
| `K` | Hover documentation |
| `<leader>ca` | Code actions |
| `<leader>cr` | Rename symbol |
| `<leader>cf` | Format code |
| `<leader>cd` | Show diagnostics |
| `[d` / `]d` | Previous/next diagnostic |

### Installation

**Linux/Mac:**
```bash
ln -s ~/configs/nvim ~/.config/nvim
```

**Windows (run as admin):**
```cmd
mklink /D "%LOCALAPPDATA%\nvim" "C:\Users\<user>\configs\nvim"
```

Then open Neovim and run `:Lazy sync` to install plugins.

## Installation

```bash
# Install tools and create symlinks
./install_windows.sh

# Create symlinks only (skip Chocolatey)
./install_windows.sh --symlinks-only
```
