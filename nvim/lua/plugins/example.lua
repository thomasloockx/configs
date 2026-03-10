-- Example plugin file
-- Add your plugins here. Each file in lua/plugins/ is automatically loaded.

return {
  -- Colorscheme
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      vim.cmd([[colorscheme tokyonight]])
    end,
  },

  -- Add more plugins below:
  -- { "tpope/vim-sleuth" },
}
