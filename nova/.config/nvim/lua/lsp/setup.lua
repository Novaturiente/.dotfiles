-- ========================================================
-- 🛠️ HELPER FUNCTIONS (LSP & DAP Setup)
-- ========================================================

local lspconfig = require("lspconfig")
local capabilities = require("cmp_nvim_lsp").default_capabilities()

-- Mason and Mason-LSPConfig setup
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
  ensure_installed = { "pyright", "rust_analyzer", "ruff", "gopls" },
})

require("mason-nvim-dap").setup({
    ensure_installed = { "python", "codelldb", "delve" }
})

-- Global LSP keybindings function
local function setup_lsp_keybindings(bufnr)
  local opts = { noremap = true, silent = true, buffer = bufnr }

  -- Navigation
  vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
  vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
  vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
  vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
  vim.keymap.set('n', 'gt', vim.lsp.buf.type_definition, opts)

  -- Documentation
  vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
  vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)

  -- Code actions and fixes
  vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)
  vim.keymap.set('v', '<leader>ca', vim.lsp.buf.code_action, opts)
  vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
  vim.keymap.set('n', '<leader>f', function() vim.lsp.buf.format({ async = true }) end, opts)

  -- Diagnostics
  vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, opts)
  vim.keymap.set('n', ']d', vim.diagnostic.goto_next, opts)
  vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, opts)
  vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, opts)
end

-- Common on_attach function for all LSP servers
function _G.on_lsp_attach(client, bufnr)
  setup_lsp_keybindings(bufnr)

  -- Set up buffer-local keymaps with which-key descriptions
  local wk = require("which-key")
  wk.register({
    g = {
      d = { vim.lsp.buf.definition, "Go to definition" },
      D = { vim.lsp.buf.declaration, "Go to declaration" },
      i = { vim.lsp.buf.implementation, "Go to implementation" },
      r = { vim.lsp.buf.references, "Go to references" },
      t = { vim.lsp.buf.type_definition, "Go to type definition" },
    },
    K = { vim.lsp.buf.hover, "Hover documentation" },
    ["<C-k>"] = { vim.lsp.buf.signature_help, "Signature help" },
    ["<leader>"] = {
      c = {
        a = { vim.lsp.buf.code_action, "Code action" },
      },
      r = {
        n = { vim.lsp.buf.rename, "Rename symbol" },
      },
      f = { function() vim.lsp.buf.format({ async = true }) end, "Format buffer" },
    },
  }, { buffer = bufnr })
end

-- Load LSP server configurations
require('lsp.servers')

-- DAP Configuration
local dap = require('dap')
dap.adapters.python = {
  type = 'executable',
  command = 'python',
  args = { '-m', 'debugpy.adapter' },
}

dap.configurations.python = {
  {
    type = 'python',
    request = 'launch',
    name = 'Launch file',
    program = '${file}',
    pythonPath = function()
      return 'python'
    end,
  },
}

require('dap-go').setup()

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
