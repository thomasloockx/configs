return {
  "nvim-telescope/telescope.nvim",
  branch = "master",
  lazy = false,
  dependencies = {
    "nvim-lua/plenary.nvim",
  },
  opts = {
    defaults = {
      path_display = { "truncate" }, -- Truncate from the start, keeping the filename visible
    },
  },
  keys = {
    { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find files" },
    { "<leader>fg", "<cmd>Telescope live_grep<cr>", desc = "Live grep" },
    { "<leader>fb", "<cmd>Telescope buffers<cr>", desc = "Buffers" },
    { "<leader>fh", "<cmd>Telescope help_tags<cr>", desc = "Help tags" },
    { "<leader>fr", "<cmd>Telescope oldfiles<cr>", desc = "Recent files" },
    { "<leader>fp", "<cmd>Telescope git_files<cr>", desc = "Git files" },
    { "<leader>fd", "<cmd>Telescope diagnostics<cr>", desc = "Diagnostics" },
    { "<leader>fs", "<cmd>Telescope git_status<cr>", desc = "Git status" },
  },
}
