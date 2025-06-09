-- ========================================================
-- LSP SERVER CONFIGURATIONS
-- ========================================================

local lspconfig = require("lspconfig")
local capabilities = require("cmp_nvim_lsp").default_capabilities()
local on_attach = _G.on_lsp_attach -- Use the global on_attach function defined in lsp/setup.lua

-- PYTHON LSP CONFIG
lspconfig.pyright.setup({
  capabilities = capabilities,
  on_attach = on_attach,
  settings = {
    pyright = {
      disableOrganizeImports = true,
    },
    python = {
      analysis = {
        ignore = { '*' },
        typeCheckingMode = "basic",
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
      },
    },
  },
})

lspconfig.ruff.setup({
  capabilities = capabilities,
  on_attach = on_attach,
  init_options = {
    settings = {
      args = {},
    }
  }
})

-- RUST LSP CONFIG
lspconfig.rust_analyzer.setup({
  capabilities = capabilities,
  on_attach = on_attach,
  settings = {
    ["rust-analyzer"] = {
      checkOnSave = {
        command = "clippy",
      },
      cargo = {
        allFeatures = true,
      },
      procMacro = {
        enable = true,
      },
    },
  },
})

-- Rust tools setup
local rt = require("rust-tools")
rt.setup({
  server = {
    capabilities = capabilities,
    on_attach = function(client, bufnr)
      on_attach(client, bufnr) -- Call the common on_attach
      local opts = { noremap = true, silent = true, buffer = bufnr }
      vim.keymap.set("n", "<C-space>", rt.hover_actions.hover_actions, opts)
      vim.keymap.set("n", "<Leader>a", rt.code_action_group.code_action_group, opts)
    end,
  },
})

-- GO LSP CONFIG
lspconfig.gopls.setup({
  capabilities = capabilities,
  on_attach = on_attach,
  settings = {
    gopls = {
      analyses = {
        unusedparams = true,
      },
      staticcheck = true,
    },
  },
})

require('go').setup({
  lsp_cfg = {
    capabilities = capabilities,
    on_attach = on_attach,
  },
  lsp_keymaps = false, -- use our own keymaps
  lsp_diag_hdlr = true,
  lsp_inlay_hints = {
    enable = true,
  },
})
