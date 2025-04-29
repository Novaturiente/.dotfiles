-- General Settings
vim.wo.number = true
vim.g.mapleader = ' '
vim.opt.clipboard = 'unnamedplus'
vim.o.mouse = 'a'  

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
-- 🔌 PLUGIN SETUP (Managed via Lazy.nvim)
-- This section includes plugin configurations for UI, LSP,
-- completions, terminal integration, file explorer, and more.
-- ========================================================
require('lazy').setup({
--  { "catppuccin/nvim", name = "catppuccin", priority = 1000 },
  {
    'projekt0n/github-nvim-theme',
    name = 'github-theme',
    lazy = false, -- make sure we load this during startup if it is your main colorscheme
    priority = 1000, -- make sure to load this before all the other start plugins
    config = function()
      require('github-theme').setup({
        -- ...
      })
  
      vim.cmd('colorscheme github_dark')
    end,
  },
  {
    'nvim-tree/nvim-tree.lua',
    requires = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      require('nvim-tree').setup {}
    end
  },

  {
    'hrsh7th/nvim-cmp',
    dependencies = {
      'hrsh7th/cmp-nvim-lsp',
      'hrsh7th/cmp-buffer',
      'hrsh7th/cmp-path',
      'hrsh7th/cmp-cmdline',
      'hrsh7th/cmp-nvim-lsp-signature-help',
    },
    config = function()
      local cmp = require('cmp')
      cmp.setup({
        completion = { completeopt = 'menu,menuone,noinsert' },
	window = {
    	  completion = cmp.config.window.bordered(),
	  documentation = cmp.config.window.bordered(),
  	},
        mapping = {
          ['<C-k>'] = cmp.mapping.select_prev_item(),
          ['<C-j>'] = cmp.mapping.select_next_item(),
          ['<C-Space>'] = cmp.mapping.complete(),
          ['<Tab>'] = cmp.mapping.confirm({ select = true }),
        },
        sources = {
          { name = 'nvim_lsp' },
          { name = 'buffer' },
          { name = 'path' },
        },
      })
    end,
  },
  {'akinsho/toggleterm.nvim', version = "*", config = true},
  { 'nvim-treesitter/nvim-treesitter', run = ':TSUpdate' },
  { 'nvim-lualine/lualine.nvim' },
  {'rcarriga/nvim-notify'},
  {'gelguy/wilder.nvim'},
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
    'nvim-telescope/telescope.nvim', tag = '0.1.8',
    dependencies = { 'nvim-lua/plenary.nvim' }
  },
  {
    'windwp/nvim-autopairs',
    event = "InsertEnter",
    config = true
  },
  {
    'neovim/nvim-lspconfig',
    config = function()
      local cmp = require('cmp')
      local capabilities = require('cmp_nvim_lsp').default_capabilities()

      cmp.setup({
        snippet = {
          expand = function(args)
            vim.fn["vsnip#anonymous"](args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ['<C-b>'] = cmp.mapping.scroll_docs(-4),
          ['<C-f>'] = cmp.mapping.scroll_docs(4),
          ['<C-Tab>'] = cmp.mapping.complete(),
          ['<C-e>'] = cmp.mapping.abort(),
          ['<Tab>'] = cmp.mapping.confirm({ select = true }),
        }),
        sources = cmp.config.sources({
          { name = 'nvim_lsp' },
          { name = 'vsnip' },
        }, {
          { name = 'buffer' },
        })
      })

      local lspconfig = require('lspconfig')
      lspconfig['pyright'].setup { capabilities = capabilities }
      lspconfig['ts_ls'].setup { capabilities = capabilities }
    end
  },
})

-- ====================
-- 🌳 UI and UX Enhancements
-- ====================
--vim.cmd.colorscheme "cyberdream"

local wilder = require('wilder')
wilder.setup({ modes = { ':', '/', '?' } })

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

-- ====================
-- 🗝️ KEYBINDINGS
-- ====================

-- File Tree
vim.api.nvim_set_keymap('n', '<leader>e', ':NvimTreeToggle<CR>', { noremap = true, silent = true })

-- Tabs
vim.api.nvim_set_keymap('n', '<C-t>', ':tabnew<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<C-Tab>', ':tabnext<CR>', { noremap = true, silent = true })
vim.api.nvim_set_keymap('n', '<C-S-Tab>', ':tabprevious<CR>', { noremap = true, silent = true })

-- Telescope
local builtin = require('telescope.builtin')
vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = 'Telescope find files' })
vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = 'Telescope live grep' })
vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Telescope buffers' })
vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Telescope help tags' })

-- Terminal Open
vim.api.nvim_set_keymap("n", "<M-v>", ":ToggleTerm direction=vertical size=50<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<C-d>", ":ToggleTerm direction=vertical size=50<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<M-h>", ":ToggleTerm direction=horizontal size=10<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<M-d>", ":ToggleTerm direction=float<CR>", { noremap = true, silent = true })

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

vim.api.nvim_set_keymap('n', '<M-Right>', ':lua ToggleTerminalFocus()<CR>', { noremap = true, silent = true })

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

vim.api.nvim_set_keymap('n', '<M-Left>', ':lua ToggleNvimTreeFocus()<CR>', { noremap = true, silent = true })

-- Auto open nvim-tree on startup
vim.cmd([[
  autocmd VimEnter * if argc() == 0 | NvimTreeOpen | endif
]])

-- Reload config
function ReloadConfig()
  dofile(vim.env.MYVIMRC)
  require('lazy').sync()
  print("Neovim configuration reloaded!")
end
--vim.api.nvim_set_keymap('n', '<leader>rr', ':lua ReloadConfig()<CR>', { noremap = true, silent = true })

-- Focus back to the editor (from terminal or NvimTree)
function FocusEditor()
  local buf_type = vim.api.nvim_buf_get_option(0, "buftype")
  local filetype = vim.bo.filetype

  if buf_type == "terminal" or filetype == "NvimTree" then
    vim.cmd("wincmd p") -- go to previous window
  end
end
vim.api.nvim_set_keymap('n', '<M-Down>', ':lua FocusEditor()<CR>', { noremap = true, silent = true })


require("notify").setup({
  timeout = 300,
  top_down = false,
})

-- Define this globally once
local Terminal = require('toggleterm.terminal').Terminal

-- Single persistent terminal instance
local python_runner = nil

function RunPythonFile()
  -- Create terminal only once
  if not python_runner then
    python_runner = Terminal:new({
      direction = "float",
      close_on_exit = true,
      hidden = true,
    })
  end

  local file = vim.fn.expand("%:p")

  -- Open if it's not open yet
  if not python_runner:is_open() then
    python_runner:toggle()
  end

  -- Send the Python run command
  python_runner:send("python3 " .. file)
end

-- Keymap
vim.api.nvim_set_keymap("n", "<leader>r", ":lua RunPythonFile()<CR>", { noremap = true, silent = true })

vim.o.guifont = "Adwaita"
