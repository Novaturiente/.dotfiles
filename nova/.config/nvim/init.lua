vim.cmd("set verbosefile=/tmp/nvim-log.txt")
vim.cmd("set verbose=10")

-- Line number
vim.wo.number = true

-- Set leader key to space
vim.g.mapleader = ' '

 -- Use the system clipboard
vim.opt.clipboard = 'unnamedplus'


-- Automatically install Lazy.nvim if not present
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    'git', 'clone', '--filter=blob:none', 'https://github.com/folke/lazy.nvim.git',
    '--branch=stable', lazypath,
  })
end
vim.opt.runtimepath:prepend(lazypath)

-- Lazy.nvim setup
require('lazy').setup({
  -- Add your plugins here
  --Theme
  { "catppuccin/nvim", name = "catppuccin", priority = 1000 },
  -- File explorer
    {
    'nvim-tree/nvim-tree.lua',
    requires = { 'nvim-tree/nvim-web-devicons' }, -- optional, for file icons
    config = function()
      require('nvim-tree').setup {}
    end
  },

  -- Completion plugins
  {
    'hrsh7th/nvim-cmp',
    dependencies = {
      'hrsh7th/cmp-nvim-lsp',
      'hrsh7th/cmp-buffer',
      'hrsh7th/cmp-path', -- Path completion for file names and paths
      'hrsh7th/cmp-cmdline',
      'hrsh7th/cmp-nvim-lsp-signature-help',
    },
    config = function()
      local cmp = require('cmp')
      cmp.setup({
        completion = {
          completeopt = 'menu,menuone,noinsert',
        },
        mapping = {
          ['<C-k>'] = cmp.mapping.select_prev_item(),
          ['<C-j>'] = cmp.mapping.select_next_item(),
          ['<C-Space>'] = cmp.mapping.complete(),
          ['<CR>'] = cmp.mapping.confirm({ select = true }),
        },
        sources = {
          { name = 'nvim_lsp' },
          { name = 'buffer' },
          { name = 'path' }, -- Enable path completion
        },
      })
    end,
  },

  --Toggle Terminal
  {'akinsho/toggleterm.nvim', version = "*", config = true},

  -- Syntax Highlighting
  { 'nvim-treesitter/nvim-treesitter', run = ':TSUpdate' },

  -- Status Line
  { 'nvim-lualine/lualine.nvim' },

  -- Notifications
  {'rcarriga/nvim-notify'},

  --Vim commands auto complete
  {'gelguy/wilder.nvim'},

  {
    'nvim-telescope/telescope.nvim', tag = '0.1.8',
-- or                              , branch = '0.1.x',
      dependencies = { 'nvim-lua/plenary.nvim' }
  },


  -- LSP Config and Setup (Add this section)
  {
    'neovim/nvim-lspconfig',
    config = function()
      -- Import and configure nvim-cmp for LSP support
      local cmp = require('cmp')
      local capabilities = require('cmp_nvim_lsp').default_capabilities()

      -- nvim-cmp setup
      cmp.setup({
        snippet = {
          expand = function(args)
            vim.fn["vsnip#anonymous"](args.body)  -- For `vsnip` users
            -- You can configure other snippet engines here if needed
            -- require('luasnip').lsp_expand(args.body) -- For `luasnip`
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ['<C-b>'] = cmp.mapping.scroll_docs(-4),
          ['<C-f>'] = cmp.mapping.scroll_docs(4),
          ['<C-Tab>'] = cmp.mapping.complete(),
          ['<C-e>'] = cmp.mapping.abort(),
          ['<CR>'] = cmp.mapping.confirm({ select = true }),
        }),
        sources = cmp.config.sources({
          { name = 'nvim_lsp' },
          { name = 'vsnip' },  -- For `vsnip` users
          -- Add other snippet engines here if required
          -- { name = 'luasnip' },
          -- { name = 'ultisnips' },
          -- { name = 'snippy' },
        }, {
          { name = 'buffer' },
        })
      })

      -- Setup LSP servers with cmp_nvim_lsp
      local lspconfig = require('lspconfig')
      lspconfig['pyright'].setup {  -- Example LSP server (Pyright)
        capabilities = capabilities
      }
      lspconfig['ts_ls'].setup {  -- Example LSP server (tsserver)
        capabilities = capabilities
      }
      -- Add more LSP servers as needed (e.g., 'clangd', 'gopls', 'rust_analyzer', etc.)
    end
  },

  -- Custom Parameters (with default)

})

-- Additional plugin configurations can go here

-- Keybinding to toggle nvim-tree
vim.api.nvim_set_keymap('n', '<leader>e', ':NvimTreeToggle<CR>', { noremap = true, silent = true })

-- Key mappings for tabs
vim.api.nvim_set_keymap('n', '<C-t>', ':tabnew<CR>', { noremap = true, silent = true }) -- Open new tab
vim.api.nvim_set_keymap('n', '<C-Tab>', ':tabnext<CR>', { noremap = true, silent = true }) -- Next tab
vim.api.nvim_set_keymap('n', '<C-S-Tab>', ':tabprevious<CR>', { noremap = true, silent = true }) -- Previous tab


-- Key bindings for telescope
local builtin = require('telescope.builtin')
vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = 'Telescope find files' })
vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = 'Telescope live grep' })
vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Telescope buffers' })
vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Telescope help tags' })


local wilder = require('wilder')
wilder.setup({modes = {':', '/', '?'}})

--Color 
vim.cmd.colorscheme "catppuccin"


--Terminal keymap
vim.api.nvim_set_keymap("n", "<Leader>tr", ":ToggleTerm direction=vertical size=50<CR>", { noremap = true, silent = true })

vim.api.nvim_set_keymap("n", "<Leader>tb", ":ToggleTerm direction=horizontal size=10<CR>", { noremap = true, silent = true })


require("toggleterm").setup {
  size = 20,  -- Adjust the default size
  open_mapping = nil,  -- Disable the default keymap
  direction = "float",  -- Ensure it's a floating terminal
}

vim.api.nvim_set_keymap("n", "<C-d>", ":ToggleTerm direction=float<CR>", { noremap = true, silent = true })
