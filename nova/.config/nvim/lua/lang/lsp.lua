local vim = vim

-- Mason Setup
require("mason").setup({
  ui = {
    icons = {
      package_installed = "",
      package_pending = "",
      package_uninstalled = "",
    },
  },
})

require("mason-lspconfig").setup({
  ensure_installed = { "clangd", "pyright", "ruff", "rust_analyzer", "lua_ls", "bashls", },
})

-- Vim Options
vim.opt.completeopt = { "menuone", "noselect", "noinsert" }
vim.opt.shortmess:append("c")
vim.opt.updatetime = 300
vim.opt.signcolumn = "yes"

-- Auto open diagnostic float on idle
vim.api.nvim_create_autocmd("CursorHold", {
  callback = function()
    vim.diagnostic.open_float(nil, { focusable = false })
  end,
})

-- LSP Setup
local lspconfig = require("lspconfig")
local capabilities = require("cmp_nvim_lsp").default_capabilities()

-- Common on_attach function
-- local function on_attach(client, bufnr)
--   client.server_capabilities.offsetEncoding = "utf-8"
--
--   -- Normal mode mappings
--   require("which-key").register({
--     ["gd"] = { vim.lsp.buf.definition, "Go to definition" },
--     ["gD"] = { vim.lsp.buf.declaration, "Go to declaration" },
--     ["gi"] = { vim.lsp.buf.implementation, "Go to implementation" },
--     ["gr"] = { vim.lsp.buf.references, "Go to references" },
--     ["gt"] = { vim.lsp.buf.type_definition, "Go to type definition" },
--     ["K"] = { vim.lsp.buf.hover, "Hover documentation" },
--     ["<C-k>"] = { vim.lsp.buf.signature_help, "Signature help" },
--     ["<leader>ca"] = { vim.lsp.buf.code_action, "Code action" },
--     ["<leader>rn"] = { vim.lsp.buf.rename, "Rename symbol" },
--     ["<leader>f"] = {
--       function() vim.lsp.buf.format({ async = true }) end,
--       "Format buffer",
--     },
--     ["[d"] = { vim.diagnostic.goto_prev, "Previous diagnostic" },
--     ["]d"] = { vim.diagnostic.goto_next, "Next diagnostic" },
--     ["<leader>e"] = { vim.diagnostic.open_float, "Line diagnostics" },
--     ["<leader>ql"] = { vim.diagnostic.setloclist, "List diagnostics" },
--   }, { mode = "n", buffer = bufnr })
--
--   -- Visual mode mappings
--   require("which-key").register({
--     ["<leader>ca"] = { vim.lsp.buf.code_action, "Code action" },
--   }, { mode = "v", buffer = bufnr })
-- end
local on_attach = function(client, bufnr)
  local buf = bufnr
  local opts = { buffer = buf, silent = true }

  local map = vim.keymap.set

  -- Go to definitions, references, implementations
  map("n", "gd", vim.lsp.buf.definition, opts)
  map("n", "gD", vim.lsp.buf.declaration, opts)
  map("n", "gr", vim.lsp.buf.references, opts)
  map("n", "gi", vim.lsp.buf.implementation, opts)
  map("n", "gt", vim.lsp.buf.type_definition, opts)

  -- Hover, signature help
  map("n", "K", vim.lsp.buf.hover, opts)
  map("n", "gk", vim.lsp.buf.signature_help, opts)

  -- Code actions & renaming
  map("n", "<leader>ca", vim.lsp.buf.code_action, opts)
  map("n", "<leader>rn", vim.lsp.buf.rename, opts)

  -- Formatting
  map("n", "<leader>f", function() vim.lsp.buf.format { async = true } end, opts)
end


-- CMP Setup
local cmp = require("cmp")
local luasnip = require("luasnip")
require("luasnip.loaders.from_vscode").lazy_load()

cmp.setup({
  snippet = {
    expand = function(args) luasnip.lsp_expand(args.body) end,
  },
  mapping = cmp.mapping.preset.insert({
    ["<Up>"] = cmp.mapping.select_prev_item(),
    ["<Down>"] = cmp.mapping.select_next_item(),
    ["<C-j>"] = cmp.mapping.select_next_item(),
    ["<C-k>"] = cmp.mapping.select_prev_item(),
    ["<C-p>"] = cmp.mapping.select_prev_item(),
    ["<C-n>"] = cmp.mapping.select_next_item(),
    ["<C-u>"] = cmp.mapping.scroll_docs(-4),
    ["<C-d>"] = cmp.mapping.scroll_docs(4),
    ["<C-Space>"] = cmp.mapping.complete(),
    ["<C-e>"] = cmp.mapping.abort(),
    ["<CR>"] = cmp.mapping.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = false }),
    ["<Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        local entry = cmp.get_selected_entry()
        if not entry then
          cmp.select_next_item({ behavior = cmp.SelectBehavior.Select })
        end
        cmp.confirm()
      elseif luasnip.expand_or_jumpable() then
        luasnip.expand_or_jump()
      else
        fallback()
      end
    end, { "i", "s" }),
    ["<S-Tab>"] = cmp.mapping(function(fallback)
      if cmp.visible() then
        cmp.select_prev_item()
      elseif luasnip.jumpable(-1) then
        luasnip.jump(-1)
      else
        fallback()
      end
    end, { "i", "s" }),
  }),
  sources = cmp.config.sources({
    { name = "nvim_lsp",                priority = 1000 },
    { name = "luasnip",                 priority = 750 },
    { name = "nvim_lsp_signature_help", priority = 700 },
  }, {
    { name = "path",     priority = 250 },
    { name = "buffer",   keyword_length = 3, priority = 50 },
    { name = "nvim_lua", priority = 300 },
    { name = "calc",     priority = 150 },
  }),
  window = {
    completion = cmp.config.window.bordered({
      winhighlight = "Normal:Pmenu,FloatBorder:Pmenu,Search:None",
    }),
    documentation = cmp.config.window.bordered({
      winhighlight = "Normal:Pmenu,FloatBorder:Pmenu,Search:None",
    }),
  },
  formatting = {
    fields = { "kind", "abbr", "menu" },
    format = function(entry, item)
      local kind_icons = {
        Text = "",
        Method = "󰆧",
        Function = "󰊕",
        Constructor = "",
        Field = "󰇽",
        Variable = "󰂡",
        Class = "󰠱",
        Property = "󰜢",
        Value = "󰎠",
        Keyword = "󰌋",
        File = "󰈙",
        Folder = "󰉋",
        Constant = "󰏿",
        Operator = "󰆕",
        TypeParameter = "󰅲",
      }
      local menu_icon = {
        nvim_lsp = "[LSP]",
        luasnip = "[Snippet]",
        buffer = "[Buffer]",
        path = "[Path]",
        nvim_lua = "[Lua]",
        calc = "[Calc]",
      }
      item.kind = string.format("%s %s", kind_icons[item.kind] or "", item.kind)
      item.menu = menu_icon[entry.source.name] or string.format("[%s]", entry.source.name)
      return item
    end,
  },
  experimental = {
    ghost_text = true,
  },
})

-- Auto format on save
require("conform").setup({
  formatters_by_ft = {
    python = { "ruff_fix" }, -- or {"ruff_fix"} if you want lint fixes too
    lua = { "stylua" },      -- example for other filetypes
  },
  format_on_save = {
    timeout_ms = 500,
    lsp_fallback = true, -- falls back to LSP formatting if no formatter is defined
  },
})

-- LSP Configurations

-- Python (Pyright)
lspconfig.pyright.setup({
  capabilities = capabilities,
  on_attach = on_attach,
  settings = {
    pyright = {
      disableLanguageServices = true,
      disableOrganizeImports = true,
    },
    python = {
      analysis = {
        typeCheckingMode = "off",
      },
    },
  },
})

-- Python (Ruff)
-- lspconfig.ruff.setup({
--   capabilities = capabilities,
--   on_attach = on_attach,
--   init_options = {
--     settings = {
--       args = {},
--     },
--   },
-- })

-- C/C++ (clangd)
lspconfig.clangd.setup({
  capabilities = capabilities,
  on_attach = on_attach,
  cmd = {
    "clangd",
    "--background-index",
    "--clang-tidy",
    "--header-insertion=never",
    "--completion-style=detailed",
    "--function-arg-placeholders=true",
  },
})

-- Rust (rust-analyzer)
lspconfig.rust_analyzer.setup({
  capabilities = capabilities,
  on_attach = on_attach,
  settings = {
    ["rust-analyzer"] = {
      cargo = { allFeatures = true },
      checkOnSave = {
        command = "clippy",
      },
    },
  },
})

-- Nix (nil language server)
lspconfig.nil_ls.setup({
  capabilities = capabilities,
  on_attach = on_attach,
  settings = {
    ['nil'] = {
      formatting = {
        command = { "nixpkgs-fmt" }, -- Optional: requires nixpkgs-fmt installed
      },
    },
  },
})

-- shell-like config
lspconfig.bashls.setup({
  capabilities = capabilities,
  on_attach = on_attach,
  filetypes = { "sh", "bash", "zsh" },
})
