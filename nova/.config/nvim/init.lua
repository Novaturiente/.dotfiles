-- ========================================================
-- ✨ GENERAL SETTINGS
-- ========================================================

local vim = vim
-- Enable line numbers
vim.wo.number = true
-- Set leader key to space
vim.g.mapleader = ' '
-- Use system clipboard
vim.opt.clipboard = 'unnamedplus'
-- Enable mouse support
vim.o.mouse = 'a'
-- Manual folding
vim.o.foldmethod = "manual"
-- Enable folding
vim.o.foldenable = true
-- Set tab to 4 spaces
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true

vim.loader.enable()
vim.opt.updatetime = 300

-- Enable persistent undo
vim.o.undofile = true
-- Set undo directory
vim.o.undodir = vim.fn.stdpath("data") .. "/undo"

vim.opt.conceallevel = 1

-- Autocommands to save and load view (including folds)
local remember_folds_group = vim.api.nvim_create_augroup("remember_folds", { clear = true })

vim.api.nvim_create_autocmd({"BufWinLeave"}, {
  pattern = "*",
  callback = function()
    if vim.fn.expand("%:p") ~= "" and vim.fn.buflisted(vim.api.nvim_get_current_buf()) == 1 then
      vim.cmd("mkview")
    end
  end,
  group = remember_folds_group,
})

vim.api.nvim_create_autocmd({"BufWinEnter"}, {
  pattern = "*",
  command = "silent! loadview",
  group = remember_folds_group,
})

vim.opt.sessionoptions:append("folds")

-- Prevent errors when plugins are not yet installed
local function safe_require(module)
  local success, result = pcall(require, module)
  if not success then
    vim.notify("Module " .. module .. " not found. Run :Lazy sync to install missing plugins.", vim.log.levels.WARN)
    return nil
  end
  return result
end

vim.lsp.set_log_level("error")
vim.opt.fsync = false

vim.api.nvim_create_autocmd("FileType", {
  pattern = "*",
  callback = function()
    pcall(function() vim.cmd("TSEnable highlight") end)
  end,
})

-- Automatically install Lazy.nvim if not present
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    'git', 'clone', '--filter=blob:none', 'https://github.com/folke/lazy.nvim.git',
    '--branch=stable', lazypath,
  })
end
vim.opt.runtimepath:prepend(lazypath)

-- ========================================================
-- 📦 PLUGIN MANAGEMENT (Lazy.nvim)
-- ========================================================

require('lazy').setup({
  -- == THEME ==
  {
    "folke/tokyonight.nvim",
    name = 'tokyonight',
    lazy = false,
    priority = 1000,
   config = function()
      require('tokyonight').setup({})
      vim.cmd('colorscheme tokyonight-night')
    end,
  },

  -- == UI Enhancements ==
  { "RRethy/vim-illuminate" },
  { "numToStr/Comment.nvim" },
  { "m-demare/hlargs.nvim" },
  { 'danilamihailov/beacon.nvim' },
  { "nvim-tree/nvim-web-devicons", opts = {} },
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    init = function()
      vim.o.timeout = true
      vim.o.timeoutlen = 300
    end,
    opts = {}
  },
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    opts = {
      dashboard = { enabled = true, example = "files"},
      explorer = { enabled = true },
      indent = { enabled = true },
      picker = { enabled = true },
      quickfile = { enabled = true },
      scroll = { enabled = true },
      words = { enabled = true },
      terminal = { enabled = true, interactive = true, },
    },
    keys = {
      { "<leader><space>", function() Snacks.picker.smart() end, desc = "Smart Find Files" },
      { "<leader>,", function() Snacks.picker.buffers() end, desc = "Buffers" },
      { "<leader>ff", function() Snacks.picker.files() end, desc = "Find Files" },
      { "<leader>fc", function() Snacks.picker.files({ cwd = vim.fn.stdpath("config") }) end, desc = "Find Config File" },
      { "<leader>fr", function() Snacks.picker.recent() end, desc = "Recent" },
      { "]]",         function() Snacks.words.jump(vim.v.count1) end, desc = "Next Reference", mode = { "n", "t" } },
      { "[[",         function() Snacks.words.jump(-vim.v.count1) end, desc = "Prev Reference", mode = { "n", "t" } },
    }
  },

  -- === File Explorer ===
  {
    'nvim-tree/nvim-tree.lua',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      require('nvim-tree').setup {}
    end
  },

  -- === Terminal ===
  {'akinsho/toggleterm.nvim', version = "*", config = true},
  {'liangxianzhe/floating-input.nvim'},

  -- === Syntax Highlighting & Text Objects ===
  {
    'nvim-treesitter/nvim-treesitter',
    run = ':TSUpdate',
    config = function()
      require('nvim-treesitter.configs').setup {
        ensure_installed = { "lua", "vim", "vimdoc", "query", "jsonc", "python", "c", "cpp", "rust" }, -- Added C/C++
        auto_install = true,
        highlight = {
          enable = true,
          additional_vim_regex_highlighting = false,
        },
        indent = { enable = true },
        rainbow = {
          enable = true,
          extended_mode = true,
          max_file_lines = nil,
        }
      }
    end
  },
  {
    'tzachar/highlight-undo.nvim',
    opts = {
      hlgroup = "HighlightUndo",
      duration = 300,
      -- Optional: ignore specific file types
      ignored_filetypes = { "neo-tree", "TelescopePrompt", ... },
    },
  },

  -- === Utility Plugins ===
  {
    'windwp/nvim-autopairs',
    event = "InsertEnter",
    config = true
  },
  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      require('lualine').setup {
        options = {
          theme = 'tokyonight-moon',
          section_separators = { left = '', right = '' },
          component_separators = { left = '|', right = '|' },
        },
        sections = {
          lualine_b = {'branch', 'diff', 'diagnostics'},
          lualine_c = {{'filename', path = 1}},
        }
      }
    end
  },
  {'rcarriga/nvim-notify'},
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    opts = {},
    dependencies = {
      "MunifTanjim/nui.nvim",
      "rcarriga/nvim-notify",
    }
  },
  {
    'nvim-telescope/telescope.nvim',
    tag = '0.1.8',
    dependencies = { 'nvim-lua/plenary.nvim' }
  },
  {
    "folke/trouble.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {},
    cmd = "Trouble",
    keys = {
      {
        "<leader>xx",
        "<cmd>Trouble diagnostics toggle<cr>",
        desc = "Diagnostics (Trouble)",
      },
      {
        "<leader>xX",
        "<cmd>Trouble diagnostics toggle filter.buf=0<cr>",
        desc = "Buffer Diagnostics (Trouble)",
      },
      {
        "<leader>cs",
        "<cmd>Trouble symbols toggle focus=false<cr>",
        desc = "Symbols (Trouble)",
      },
      {
        "<leader>cl",
        "<cmd>Trouble lsp toggle focus=false win.position=right<cr>",
        desc = "LSP Definitions / references / ... (Trouble)",
      },
      {
        "<leader>xL",
        "<cmd>Trouble loclist toggle<cr>",
        desc = "Location List (Trouble)",
      },
      {
        "<leader>xQ",
        "<cmd>Trouble qflist toggle<cr>",
        desc = "Quickfix List (Trouble)",
      },
    },
  },
  {
    "epwalsh/obsidian.nvim",
    version = "*",
    lazy = true,
    ft = "markdown",
    ui = { enable = true },

    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    opts = {
      workspaces = {
        {
          name = "notes",
          path = "~/Notes",
        },
      },
      follow_url_func = function(url)
        vim.fn.jobstart({"xdg-open", url})
      end,
    },
  },

  -- === Development Plugins ===
  -- LSP
  { "neovim/nvim-lspconfig" },
  { "williamboman/mason.nvim", build = ":MasonUpdate", config = true },
  { "williamboman/mason-lspconfig.nvim" },
  {"mfussenegger/nvim-dap"},

  -- Autocompletion
  { "hrsh7th/nvim-cmp" },
  { "hrsh7th/cmp-nvim-lsp" },
  { "hrsh7th/cmp-buffer" },
  { "hrsh7th/cmp-path" },
  { "hrsh7th/cmp-nvim-lua" },
  { "hrsh7th/cmp-nvim-lsp-signature-help" },
  { "L3MON4D3/LuaSnip" },
  { "saadparwaiz1/cmp_luasnip",
     dependencies = {
      "rafamadriz/friendly-snippets",
    },
  },

  -- LSP UI
  {
    "nvimdev/lspsaga.nvim",
    event = "LspAttach",
    config = true,
  },
})

-- ========================================================
-- 🌳 UI and UX Enhancements (Configuration)
-- ========================================================

require("noice").setup({
  lsp = {
    override = {
      ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
      ["vim.lsp.util.stylize_markdown"] = true,
      ["cmp.entry.get_documentation"] = true,
    },
  },
  presets = {
    bottom_search = true,
    command_palette = true,
    long_message_to_split = true,
    inc_rename = false,
    lsp_doc_border = false,
  },
})

vim.diagnostic.config({
  virtual_text = { prefix = '●', source = "always" },
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = " ",
      [vim.diagnostic.severity.WARN]  = " ",
      [vim.diagnostic.severity.HINT]  = " ",
      [vim.diagnostic.severity.INFO]  = " ",
    },
  },
  underline = true,
  update_in_insert = false,
  severity_sort = true,
  float = {
    focusable = false,
    style = 'minimal',
    border = 'rounded',
    source = 'always',
    header = '',
    prefix = '',
  },
})

require("notify").setup({
  timeout = 300,
  top_down = false,
})

-- Initialize which-key
require("which-key").setup({
  plugins = {
    marks = true,
    registers = true,
    spelling = {
      enabled = true,
      suggestions = 20,
    },
    presets = {
      operators = true,
      motions = true,
      text_objects = true,
      windows = true,
      nav = true,
      z = true,
      g = true,
    },
  },
  window = {
    border = "rounded",
    position = "bottom",
    margin = { 1, 0, 1, 0 },
    padding = { 2, 2, 2, 2 },
  },
})

-- ========================================================
-- 🛠️ HELPER FUNCTIONS
-- ========================================================

-- mason & LSP setup
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
  ensure_installed = { "pyright", "ruff", "clangd" }, -- Added clangd for C/C++
})

local lspconfig = require("lspconfig")
local capabilities = require("cmp_nvim_lsp").default_capabilities()

-- LSP settings
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

-- Additional diagnostic configuration
vim.diagnostic.config({
  virtual_text = {
    prefix = '●',
    source = "always",
  },
  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
  float = {
    focusable = false,
    style = 'minimal',
    border = 'rounded',
    source = 'always',
    header = '',
    prefix = '',
  },
})

-- Run current file
local Terminal = require("toggleterm.terminal").Terminal

function RunFile()
  local ext = vim.fn.expand('%:e')
  local file = vim.fn.expand('%')
  local cmd = nil

  if ext == "py" then
    cmd = 'fish -c "uv run ' .. file .. '; fish"'
  -- Added C/C++ run commands
  elseif ext == "c" then
    cmd = string.format('fish -c "gcc -g %s -o %s && ./%s; fish"', file, vim.fn.expand('%:r'), vim.fn.expand('%:r'))
  elseif ext == "cpp" then
    cmd = string.format('fish -c "g++ -g %s -o %s && ./%s; fish"', file, vim.fn.expand('%:r'), vim.fn.expand('%:r'))
  elseif ext == "rs" then
  cmd = 'fish -c "cargo run; fish"'
  else
    print("No run command for extension: " .. ext)
    return
  end

  local term = Terminal:new({
    cmd = cmd,
    direction = "float",
    close_on_exit = true,
    hidden = true
  })
  term:toggle()
end

-- Configure Undo history
require('highlight-undo').setup({ duration = 600 })

-- ========================================================
-- 🗝️ KEYBINDINGS
-- ========================================================

-- Register keybindings with which-key
local wk = require("which-key")

-- File Tree
require("which-key").add {
  { "<leader>o", ":NvimTreeToggle<CR>", desc = "Toggle file explorer" },
}

-- Tabs
require("which-key").add {
  { "<C-t", ":tabnew<CR>", desc = "New tab" },
}

-- Telescope
local builtin = require('telescope.builtin')
require("which-key").add {
  { "<leader>fg", builtin.live_grep, desc = "Live grep" },
  { "<leader>fb", builtin.buffers,   desc = "Find buffers" },
  { "<leader>fh", builtin.help_tags, desc = "Help tags" },
}

-- Terminal
require("which-key").add {
  { "<M-v>", ":ToggleTerm direction=vertical size=50<CR>",  desc = "Vertical terminal" },
  { "<M-d>", ":ToggleTerm direction=vertical size=50<CR>",  desc = "Vertical terminal" },
  { "<M-h>", ":ToggleTerm direction=horizontal size=10<CR>",desc = "Horizontal terminal" },
  { "<C-d>", ":ToggleTerm direction=float<CR>",            desc = "Floating terminal" },
}

-- Buffer navigation
require("which-key").add {
  { "<M-Right>", ":bnext<CR>",     desc = "Next buffer" },
  { "<M-Left>",  ":bprev<CR>",     desc = "Previous buffer" },
  { "<leader>q", ":bd<CR>",        desc = "Close buffer" },
}

-- Run file
require("which-key").add {
  { "<leader>r", RunFile, desc = "Run current file" },
}

-- Diagnostics
require("which-key").add {
  {
    "<leader>cc",
    function()
      -- Copy all diagnostics on the current line to the clipboard
      local diagnostics = vim.diagnostic.get(0, {
        lnum = vim.api.nvim_win_get_cursor(0)[1] - 1,
      })
      if vim.tbl_isempty(diagnostics) then
        print("No diagnostics to copy")
        return
      end
      local lines = {}
      for _, d in ipairs(diagnostics) do
        table.insert(lines, d.message)
      end
      local text = table.concat(lines, "\n")
      vim.fn.setreg("+", text)
      vim.notify("Copied diagnostic to clipboard", vim.log.levels.INFO)
    end,
    desc = "Copy diagnostic to clipboard",
  },
  {
    "<leader>cx",
    function()
      -- Append "# type: ignore" to suppress a Pyright warning on this line
      local line = vim.api.nvim_get_current_line()
      if not line:find("# type: ignore") then
        vim.api.nvim_set_current_line(line .. "  # type: ignore")
        vim.notify("Added '# type: ignore' to suppress Pyright warning", vim.log.levels.INFO)
      else
        vim.notify("'# type: ignore' already present", vim.log.levels.WARN)
      end
    end,
    desc = "Suppress Pyright error",
  },
}

-- Open specific files
wk.add{
  {"<leader>wn", "<cmd>edit ~/.config/nvim/init.lua<cr>", desc = "Open Neovim config"},
  {"<leader>ww", "<cmd>edit ~/Notes/index.md<cr>", desc = "Open Notes"},
  {"<leader>hc", "<cmd>edit ~/.config/hypr/hyprland.conf<cr>", desc = "Open Notes"},
  {"<leader>hb", "<cmd>edit ~/.config/hypr/binds.conf<cr>", desc = "Open Notes"}
}

-- Obsidian keybindings
wk.add{
  {"<leader>os", ":ObsidianSearch<cr>", desc = "Obsidian Search"},
  {"<leader>on", ":ObsidianNew<cr>", desc = "Obsidian new file"}
}
