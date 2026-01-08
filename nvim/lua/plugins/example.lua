-- Example plugin file
-- Add your plugins here. Each file in lua/plugins/ is automatically loaded.

return {
  -- Colorscheme
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
    config = function()
      vim.cmd([[colorscheme catppuccin-mocha]])
    end,
  },

  -- Add more plugins below:
  -- { "tpope/vim-sleuth" },
}
