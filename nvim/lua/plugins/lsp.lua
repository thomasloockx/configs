return {
  -- Mason: LSP server installer
  {
    "williamboman/mason.nvim",
    lazy = false,
    config = function()
      require("mason").setup()
    end,
  },

  -- Bridge between mason and lspconfig
  {
    "williamboman/mason-lspconfig.nvim",
    lazy = false,
    dependencies = {
      "williamboman/mason.nvim",
    },
    opts = {
      ensure_installed = {
        "pyright",           -- Python
        "clangd",            -- C/C++
        "ts_ls",             -- TypeScript/JavaScript
      },
    },
  },

  -- LSP configuration
  {
    "neovim/nvim-lspconfig",
    lazy = false,
    dependencies = {
      "williamboman/mason.nvim",
      "williamboman/mason-lspconfig.nvim",
    },
    config = function()
      -- Keybindings when LSP attaches to a buffer
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local opts = { buffer = args.buf }
          -- Navigation
          vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
          vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
          vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
          vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
          vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
          -- Actions
          vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, { buffer = args.buf, desc = "Code Action" })
          vim.keymap.set("n", "<leader>cr", vim.lsp.buf.rename, { buffer = args.buf, desc = "Rename Symbol" })
          vim.keymap.set("n", "<leader>cf", function() vim.lsp.buf.format({ async = true }) end, { buffer = args.buf, desc = "Format Buffer" })
          -- Diagnostics
          vim.keymap.set("n", "<leader>cd", vim.diagnostic.open_float, { buffer = args.buf, desc = "Line Diagnostics" })
          vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
          vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
        end,
      })

      -- Setup LSP servers using vim.lsp.config (modern approach)
      vim.lsp.config("pyright", {})
      vim.lsp.config("clangd", {})
      vim.lsp.config("ts_ls", {})

      -- Enable the configured servers
      vim.lsp.enable({ "pyright", "clangd", "ts_ls" })
    end,
  },
}
