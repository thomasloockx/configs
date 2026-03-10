return {
  "folke/which-key.nvim",
  event = "VeryLazy",
  opts = {
    -- Modern preset (similar to LazyVim style)
    preset = "modern",
    -- Delay before showing the popup (in ms)
    delay = 200,
    -- Document existing key chains
    spec = {
      { "<leader>f", group = "find/files" },
      { "<leader>g", group = "git" },
      { "<leader>c", group = "code" },
      { "<leader>s", group = "symbols" },
      -- { "<leader>b", group = "buffer" },
    },
  },
  keys = {
    {
      "<leader>?",
      function()
        require("which-key").show({ global = false })
      end,
      desc = "Buffer Local Keymaps",
    },
  },
}
