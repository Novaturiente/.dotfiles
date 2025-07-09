-- mason setup
require("mason").setup({
    ui = {
        icons = {
            package_installed = "",
            package_pending = "",
            package_uninstalled = "",
        },
    }
})

require("mason-lspconfig").setup({
  ensure_installed = { "pyright", "ruff", "clangd" },
})


-- LSP settings
local lspconfig = require("lspconfig")
local capabilities = require("cmp_nvim_lsp").default_capabilities()
vim.opt.completeopt = {'menuone', 'noselect', 'noinsert'}
vim.opt.shortmess = vim.opt.shortmess + { c = true}
vim.api.nvim_set_option('updatetime', 300) 

vim.cmd([[
set signcolumn=yes
autocmd CursorHold * lua vim.diagnostic.open_float(nil, { focusable = false })
]])

-- Common on_attach function for all LSP servers
local function on_attach(client, bufnr)
  -- Set up buffer-local keymaps with which-key descriptions
  client.server_capabilities.offsetEncoding = "utf-8"
  
  -- This single block now handles both creating the keymap AND registering it with which-key
  require("which-key").add({
    mode = "n", -- Set the mode for all keys in this table
    { "gd", vim.lsp.buf.definition, desc = "Go to definition" },
    { "gD", vim.lsp.buf.declaration, desc = "Go to declaration" },
    { "gi", vim.lsp.buf.implementation, desc = "Go to implementation" },
    { "gr", vim.lsp.buf.references, desc = "Go to references" },
    { "gt", vim.lsp.buf.type_definition, desc = "Go to type definition" },
    { "K",  vim.lsp.buf.hover, desc = "Hover documentation" },
    { "<C-k>", vim.lsp.buf.signature_help, desc = "Signature help" },
    { "<leader>ca", vim.lsp.buf.code_action, desc = "Code action" },
    { "<leader>rn", vim.lsp.buf.rename, desc = "Rename symbol" },
    { "<leader>f", function() vim.lsp.buf.format({ async = true }) end, desc = "Format buffer" },
    
    -- You can also add your diagnostic keybindings here for consistency
    { "[d", vim.diagnostic.goto_prev, desc = "Previous diagnostic" },
    { "]d", vim.diagnostic.goto_next, desc = "Next diagnostic" },
    { "<leader>e", vim.diagnostic.open_float, desc = "Line diagnostics" },
    { "<leader>ql", vim.diagnostic.setloclist, desc = "List diagnostics" },

  }, { buffer = bufnr })

  -- If you have mappings for other modes (e.g., visual mode), you can add another block
  require("which-key").add({
    mode = "v",
    { "<leader>ca", vim.lsp.buf.code_action, desc = "Code action" },
  }, { buffer = bufnr })
end

-- Auto format on save
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = { "*.lua", "*.py", "*.c", "*.cpp", "*.h", "*.hpp", "*.rs" }, -- Added C/C++ file types
  callback = function()
    vim.lsp.buf.format({ async = false })
  end,
})

-- Completion Plugin Setup
local cmp = require'cmp'
local luasnip = require('luasnip')

-- Load friendly-snippets
require('luasnip.loaders.from_vscode').lazy_load()

cmp.setup({
  snippet = {
    expand = function(args)
      luasnip.lsp_expand(args.body)
    end,
  },
  mapping = cmp.mapping.preset.insert({
    ['<Up>'] = cmp.mapping.select_prev_item(),
    ['<Down>'] = cmp.mapping.select_next_item(),
    ['<C-j>'] = cmp.mapping.select_next_item(),
    ['<C-k>'] = cmp.mapping.select_prev_item(),
    ['<C-p>'] = cmp.mapping.select_prev_item(),
    ['<C-n>'] = cmp.mapping.select_next_item(),
    ['<C-u>'] = cmp.mapping.scroll_docs(-4),
    ['<C-d>'] = cmp.mapping.scroll_docs(4),
    ['<C-Space>'] = cmp.mapping.complete(),
    ['<C-e>'] = cmp.mapping.abort(),
    ['<CR>'] = cmp.mapping.confirm({
      behavior = cmp.ConfirmBehavior.Replace,
      select = false,
    }),
    ['<Tab>'] = cmp.mapping(function(fallback)
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
    ['<S-Tab>'] = cmp.mapping(function(fallback)
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
    { name = 'nvim_lsp', priority = 1000 },
    { name = 'luasnip', priority = 750 },
    { name = 'nvim_lsp_signature_help', priority = 700 },
  }, {
    { name = 'path', priority = 250 },
    { name = 'buffer', keyword_length = 3, priority = 50 },
    { name = 'nvim_lua', priority = 300 },
    { name = 'calc', priority = 150 },
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
    fields = {'kind', 'abbr', 'menu'},
    format = function(entry, item)
      local kind_icons = {
        Text = "",
        Method = "󰆧",
        Function = "󰊕",
        Constructor = "",
        Field = "󰇽",
        Variable = "󰂡",
        Class = "󰠱",
        Interface = "",
        Module = "",
        Property = "󰜢",
        Unit = "",
        Value = "󰎠",
        Enum = "",
        Keyword = "󰌋",
        Snippet = "",
        Color = "󰏘",
        File = "󰈙",
        Reference = "",
        Folder = "󰉋",
        EnumMember = "",
        Constant = "󰏿",
        Struct = "",
        Event = "",
        Operator = "󰆕",
        TypeParameter = "󰅲",
      }
      
      local menu_icon = {
        nvim_lsp = '[LSP]',
        luasnip = '[Snippet]',
        buffer = '[Buffer]',
        path = '[Path]',
        nvim_lua = '[Lua]',
        calc = '[Calc]',
      }
      
      item.kind = string.format('%s %s', kind_icons[item.kind] or "", item.kind)
      item.menu = menu_icon[entry.source.name] or string.format('[%s]', entry.source.name)
      
      return item
    end,
  },
  experimental = {
    ghost_text = true,
  },
})

-- PYTHON LSP CONFIG (Kept)
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

-- C/C++ LSP CONFIG (Added)
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

-- Rust LSP CONFIG
lspconfig.rust_analyzer.setup({
  capabilities = capabilities,
  on_attach = on_attach,
  settings = {
    ["rust-analyzer"] = {
      cargo = { allFeatures = true },
      checkOnSave = {
        command = "clippy"
      },
    }
  }
})
