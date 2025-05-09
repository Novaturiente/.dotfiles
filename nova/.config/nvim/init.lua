-- ========================================================
-- ✨ GENERAL SETTINGS
-- ========================================================

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

vim.loader.enable()
vim.opt.updatetime = 300



-- Autocommands to save and load view (including folds)
local remember_folds_group = vim.api.nvim_create_augroup("remember_folds", { clear = true })

vim.api.nvim_create_autocmd({"BufWinLeave"}, {
  pattern = "*",
  callback = function()
    -- Check if the buffer has a valid file name
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

-- Optional: Ensure 'folds' is included in sessionoptions if you use sessions
vim.opt.sessionoptions:append("folds")

-- Prevent errors when plugins are not yet installed
-- This function attempts to require a module safely.
local function safe_require(module)
  local success, result = pcall(require, module)
  if not success then
    vim.notify("Module " .. module .. " not found. Run :Lazy sync to install missing plugins.", vim.log.levels.WARN)
    return nil
  end
  return result
end

-- Set a timeout for LSP initialization to prevent hanging and reduce log verbosity
vim.lsp.set_log_level("error")

-- Make sure filesystem notifications don't cause errors
vim.opt.fsync = false

-- Fix potential treesitter errors by enabling highlighting on FileType
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
    -- config = function()
    --   require('tokyonight').setup({})
    --   vim.cmd('colorscheme tokyonight-night')
    -- end,
  },
  {
    "scottmckendry/cyberdream.nvim",
    lazy = false,
    priority = 1000,
  },

  { "RRethy/vim-illuminate" },
  { "numToStr/Comment.nvim" },
  { "m-demare/hlargs.nvim" },
  { 'danilamihailov/beacon.nvim' },
  { "nvim-tree/nvim-web-devicons", opts = {} },
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    ---@type snacks.Config
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
    dependencies = { 'nvim-tree/nvim-web-devicons' }, -- Icons for file types
    config = function()
      require('nvim-tree').setup {}
    end
  },

  -- === Terminal ===
  {'akinsho/toggleterm.nvim', version = "*", config = true}, -- Toggleable terminal

  -- === Syntax Highlighting & Text Objects ===
  {
    'nvim-treesitter/nvim-treesitter',
    run = ':TSUpdate', -- Command to update parsers
    config = function()
      require('nvim-treesitter.configs').setup {
        -- Keep general parsers, remove language-specific ones if desired
        ensure_installed = { "lua", "vim", "vimdoc", "query", "jsonc", "python", "rust", "toml" }, -- Keeping general parsers
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

  -- === Utility Plugins ===
  {
    'windwp/nvim-autopairs', -- Auto pair brackets, quotes, etc.
    event = "InsertEnter",
    config = true
  },
  {
    'nvim-lualine/lualine.nvim', -- Status line plugin
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
  {'rcarriga/nvim-notify'}, -- Notification system
  {
    "folke/noice.nvim", -- UI improvements for messages, cmdline & popupmenu
    event = "VeryLazy",
    opts = {},
    dependencies = {
      "MunifTanjim/nui.nvim",
      "rcarriga/nvim-notify",
    }
  },
  {
    'nvim-telescope/telescope.nvim', -- Fuzzy finder
    tag = '0.1.8',
    dependencies = { 'nvim-lua/plenary.nvim' }
  },
  -- Replaced trouble.nvim configuration block
  {
    "folke/trouble.nvim", -- Enhanced diagnostics viewer
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {}, -- for default options, refer to the configuration section for custom setup.
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

  -- === Development Plugins ===
  -- LSP
  { "neovim/nvim-lspconfig" },
  { "williamboman/mason.nvim", build = ":MasonUpdate", config = true },
  { "williamboman/mason-lspconfig.nvim" },
  {"mfussenegger/nvim-dap"},
  {"jay-babu/mason-nvim-dap.nvim"},
  {'simrat39/rust-tools.nvim'},

  -- Autocompletion
  { "hrsh7th/nvim-cmp" },
  { "hrsh7th/cmp-nvim-lsp" },
  { "hrsh7th/cmp-buffer" },
  { "hrsh7th/cmp-path" },
  { "hrsh7th/cmp-nvim-lua" },
  { "hrsh7th/cmp-nvim-lsp-signature-help" },
  { "hrsh7th/cmp-vsnip" },
  { "hrsh7th/vim-vsnip" },
  { "L3MON4D3/LuaSnip" },
  { "saadparwaiz1/cmp_luasnip",
     dependencies = {
      "rafamadriz/friendly-snippets", -- optional
    },
  },

  -- LSP UI
  {
    "nvimdev/lspsaga.nvim",
    event = "LspAttach",
    config = true,
  },
  {
    'benomahony/uv.nvim',
    config = function()
      require('uv').setup()
    end,
  },
})

-- ========================================================
-- 🌳 UI and UX Enhancements (Configuration)
-- ========================================================

-- noice.nvim configuration (moved from plugin section for clarity)
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

-- Set up diagnostic symbols (moved from UI section for clarity)
local signs = { Error = " ", Warn = " ", Hint = " ", Info = " " }
for type, icon in pairs(signs) do
  local hl = "DiagnosticSign" .. type
  vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
end

-- notify.nvim configuration (moved from plugin section for clarity)
require("notify").setup({
  timeout = 300,
  top_down = false,
})

-- theme configuration
require("cyberdream").setup({
    variant = "default",
    transparent = true,
    saturation = 0.7,
    italic_comments = false,
    -- Apply a modern borderless look to pickers like Telescope, Snacks Picker & Fzf-Lua
    borderless_pickers = false,
    terminal_colors = true,
    cache = false,
})
vim.cmd("colorscheme cyberdream")

-- ========================================================
-- 🛠️ HELPER FUNCTIONS
-- ========================================================

-- mason & LSP setup
require("mason").setup({
    ui = {
        icons = {
            package_installed = "",
            package_pending = "",
            package_uninstalled = "",
        },
    }
})
require("mason-lspconfig").setup({
  ensure_installed = { "pyright", "rust_analyzer", "ruff" },
})
require("mason-nvim-dap").setup({
    ensure_installed = { "python", "codelldb" }
})

local lspconfig = require("lspconfig")
local capabilities = require("cmp_nvim_lsp").default_capabilities()

vim.opt.completeopt = {'menuone', 'noselect', 'noinsert'}
vim.opt.shortmess = vim.opt.shortmess + { c = true}
vim.api.nvim_set_option('updatetime', 300) 

vim.cmd([[
set signcolumn=yes
autocmd CursorHold * lua vim.diagnostic.open_float(nil, { focusable = false })
]])

-- PYTHON LSP CONFIG

require('lspconfig').pyright.setup {
  settings = {
    pyright = {
    },
    python = {
      analysis = {
      },
    },
  },
}

lspconfig.ruff.setup({})

-- == RUST LSP CONFIG == 
lspconfig.rust_analyzer.setup({
  capabilities = require("cmp_nvim_lsp").default_capabilities(),
  settings = {
    ["rust-analyzer"] = {
      checkOnSave = {
        command = "clippy", -- optional
      },
    },
  },
})

local rt = require("rust-tools")

rt.setup({
  server = {
    on_attach = function(_, bufnr)
      -- Hover actions
      vim.keymap.set("n", "<C-space>", rt.hover_actions.hover_actions, { buffer = bufnr })
      -- Code action groups
      vim.keymap.set("n", "<Leader>a", rt.code_action_group.code_action_group, { buffer = bufnr })
    end,
  },
})


--Completion Plugin Setup
local cmp = require'cmp'
cmp.setup({
  -- Enable LSP snippets
  snippet = {
    expand = function(args)
        vim.fn["vsnip#anonymous"](args.body)
    end,
  },
  mapping = {
    ['<C-p>'] = cmp.mapping.select_prev_item(),
    ['<C-n>'] = cmp.mapping.select_next_item(),
    -- Add tab support
    ['<S-Tab>'] = cmp.mapping.select_prev_item(),
    ['<C-S-f>'] = cmp.mapping.scroll_docs(-4),
    ['<C-f>'] = cmp.mapping.scroll_docs(4),
    ['<C-Space>'] = cmp.mapping.complete(),
    ['<C-e>'] = cmp.mapping.close(),
    ['<Tab>'] = cmp.mapping.confirm({
      behavior = cmp.ConfirmBehavior.Insert,
      select = true,
    })
  },
  -- Installed sources:
  sources = {
    { name = 'path' },                              -- file paths
    { name = 'nvim_lsp', keyword_length = 3 },      -- from language server
    { name = 'nvim_lsp_signature_help'},            -- display function signatures with current parameter emphasized
    { name = 'nvim_lua', keyword_length = 2},       -- complete neovim's Lua runtime API such vim.lsp.*
    { name = 'buffer', keyword_length = 2 },        -- source current buffer
    { name = 'vsnip', keyword_length = 2 },         -- nvim-cmp source for vim-vsnip 
    { name = 'calc'},                               -- source for math calculation
  },
  window = {
      completion = cmp.config.window.bordered(),
      documentation = cmp.config.window.bordered(),
  },
  formatting = {
      fields = {'menu', 'abbr', 'kind'},
      format = function(entry, item)
          local menu_icon ={
              nvim_lsp = 'λ',
              vsnip = '⋗',
              buffer = 'Ω',
              path = '🖫',
          }
          item.menu = menu_icon[entry.source.name]
          return item
      end,
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

vim.keymap.set("n", "<leader>r", RunFile, { noremap = true, silent = true })


-- ========================================================
-- 🗝️ KEYBINDINGS
-- ========================================================

-- File Tree
vim.api.nvim_set_keymap('n', '<leader>e', ':NvimTreeToggle<CR>', { noremap = true, silent = true, desc = "NvimTree: Toggle" })

-- Tabs
vim.api.nvim_set_keymap('n', '<C-t>', ':tabnew<CR>', { noremap = true, silent = true, desc = "Tab: New" })
vim.api.nvim_set_keymap('n', '<C-Tab>', ':tabnext<CR>', { noremap = true, silent = true, desc = "Tab: Next" })
vim.api.nvim_set_keymap('n', '<C-S-Tab>', ':tabprevious<CR>', { noremap = true, silent = true, desc = "Tab: Previous" })

-- Telescope
local builtin = require('telescope.builtin')
-- vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = 'Telescope: Find Files' })
vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = 'Telescope: Live Grep' })
vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Telescope: Buffers' })
vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Telescope: Help Tags' })

-- Terminal Open
vim.api.nvim_set_keymap("n", "<M-v>", ":ToggleTerm direction=vertical size=50<CR>", { noremap = true, silent = true, desc = "ToggleTerm: Vertical" })
vim.api.nvim_set_keymap("n", "<M-d>", ":ToggleTerm direction=vertical size=50<CR>", { noremap = true, silent = true, desc = "ToggleTerm: Vertical (Alt)" })
vim.api.nvim_set_keymap("n", "<M-h>", ":ToggleTerm direction=horizontal size=10<CR>", { noremap = true, silent = true, desc = "ToggleTerm: Horizontal" })
vim.api.nvim_set_keymap("n", "<C-d>", ":ToggleTerm direction=float<CR>", { noremap = true, silent = true, desc = "ToggleTerm: Float" })

-- Toggle Terminal Focus
function ToggleTerminalFocus()
  local term_buf_type = "terminal"
  local buf_type = vim.api.nvim_buf_get_option(0, "buftype")

  if buf_type == term_buf_type then
    vim.cmd("wincmd p")
  else
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local buf = vim.api.nvim_win_get_buf(win)
      local btype = vim.api.nvim_buf_get_option(buf, "buftype")
      if btype == term_buf_type then
        vim.api.nvim_set_current_win(win)
        return
      end
    end
  end
end
vim.api.nvim_set_keymap('n', '<M-Right>', ':lua ToggleTerminalFocus()<CR>', { noremap = true, silent = true, desc = "Focus Terminal" })

-- Toggle NvimTree Focus
function ToggleNvimTreeFocus()
  local view = require('nvim-tree.view')
  if view.is_visible() then
    if vim.fn.winnr() == view.get_winnr() then
      vim.cmd('wincmd p')
    else
      view.focus()
    end
  end
end
vim.api.nvim_set_keymap('n', '<M-Left>', ':lua ToggleNvimTreeFocus()<CR>', { noremap = true, silent = true, desc = "Focus Terminal" })

-- Focus back to the editor (from terminal or NvimTree)
function FocusEditor()
  local buf_type = vim.api.nvim_buf_get_option(0, "buftype")
  local filetype = vim.bo.filetype

  if buf_type == "terminal" or filetype == "NvimTree" then
    vim.cmd("wincmd p") -- go to previous window
  end
end
vim.api.nvim_set_keymap('n', '<M-Down>', ':lua FocusEditor()<CR>', { noremap = true, silent = true, desc = "Focus Editor" })

-- Reload config
function ReloadConfig()
  dofile(vim.env.MYVIMRC)
  require('lazy').sync()
  print("Neovim configuration reloaded!")
end
vim.api.nvim_set_keymap('n', '<leader>rc', ':lua ReloadConfig()<CR>', { noremap = true, silent = true, desc = "Reload Config" })

-- Keybinding Cheatsheet
require("keybindings.cheatsheet")
vim.api.nvim_set_keymap("n", "<leader>xs", ":lua require'keybindings.cheatsheet'.show_cheat_sheet()<CR>", { noremap = true, silent = true, desc = "Show Keybinding Cheatsheet" })


-- ========================================================
-- 📂 AUTOCOMMANDS
-- ========================================================

-- Auto open nvim-tree on startup if no file is opened
-- vim.cmd([[
--   autocmd VimEnter * if argc() == 0 | NvimTreeOpen | endif
-- ]])
--
--
-- vim.api.nvim_create_autocmd("LspAttach", {
--   group = vim.api.nvim_create_augroup('lsp_attach_disable_ruff_hover', { clear = true }),
--   callback = function(args)
--     local client = vim.lsp.get_client_by_id(args.data.client_id)
--     if client == nil then
--       return
--     end
--     if client.name == 'ruff' then
--       -- Disable hover in favor of Pyright
--       client.server_capabilities.hoverProvider = false
--     end
--   end,
--   desc = 'LSP: Disable hover capability from Ruff',
-- })
