-- Set leader key before lazy
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Editor options
vim.opt.number = true         -- Show line numbers
vim.opt.relativenumber = true -- Show relative line numbers
vim.opt.syntax = "on"         -- Enable syntax highlighting
vim.opt.termguicolors = true  -- Enable true colors

-- Diagnostic display settings
vim.diagnostic.config({
  virtual_text = true,      -- Show diagnostics inline
  signs = true,             -- Show signs in the gutter
  underline = true,         -- Underline the problematic code
  update_in_insert = false, -- Don't update while typing
  severity_sort = true,     -- Sort by severity
})

-- Load lazy.nvim
require("lazy-setup")
