-- Set leader key before lazy
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Editor options
vim.opt.number = true         -- Show line numbers
vim.opt.relativenumber = false -- Disable relative line numbers
vim.opt.syntax = "on"         -- Enable syntax highlighting
vim.opt.termguicolors = true  -- Enable true colors

-- Indentation (4 spaces, no tabs)
vim.opt.expandtab = true      -- Use spaces instead of tabs
vim.opt.tabstop = 4           -- Tab displays as 4 spaces
vim.opt.shiftwidth = 4        -- Indent with 4 spaces
vim.opt.softtabstop = 4       -- Tab key inserts 4 spaces

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
