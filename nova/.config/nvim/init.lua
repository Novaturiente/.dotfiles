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
--#####################################################################################################################################
  {
    "yetone/avante.nvim",
    event = "VeryLazy",
    version = false, -- Set this to "*" to always pull the latest release version, or set it to false to update to the latest code changes.
    opts = {
      -- add any opts here
      -- for example
      provider = "ollama",
      ollama = {
        model = "gemma3:4b", -- your desired model (or use gpt-4o, etc.)
      },
    },
    -- if you want to build from source then do `make BUILD_FROM_SOURCE=true`
    build = "make",
    -- build = "powershell -ExecutionPolicy Bypass -File Build.ps1 -BuildFromSource false" -- for windows
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "stevearc/dressing.nvim",
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      --- The below dependencies are optional,
      "echasnovski/mini.pick", -- for file_selector provider mini.pick
      "nvim-telescope/telescope.nvim", -- for file_selector provider telescope
      "hrsh7th/nvim-cmp", -- autocompletion for avante commands and mentions
      "ibhagwan/fzf-lua", -- for file_selector provider fzf
      "nvim-tree/nvim-web-devicons", -- or echasnovski/mini.icons
      "zbirenbaum/copilot.lua", -- for providers='copilot'
      {
        -- support for image pasting
        "HakonHarnes/img-clip.nvim",
        event = "VeryLazy",
        opts = {
          -- recommended settings
          default = {
            embed_image_as_base64 = false,
            prompt_for_file_name = false,
            drag_and_drop = {
              insert_mode = true,
            },
            -- required for Windows users
            use_absolute_path = true,
          },
        },
      },
      {
        -- Make sure to set this up properly if you have lazy=true
        'MeanderingProgrammer/render-markdown.nvim',
        opts = {
          file_types = { "markdown", "Avante" },
        },
        ft = { "markdown", "Avante" },
      },
    },
  }
--
--
--
--
--###########################################################################################
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

-- Define a function to toggle focus between NvimTree and the previous window
function ToggleNvimTreeFocus()
  local view = require('nvim-tree.view')
  if view.is_visible() then
    if vim.fn.winnr() == view.get_winnr() then
      vim.cmd('wincmd p') -- Focus on the previous window
    else
      view.focus() -- Focus on NvimTree
    end
  end
end

-- Create a keybinding to toggle NvimTree focus
vim.api.nvim_set_keymap('n', '<M-Left>', ':lua ToggleNvimTreeFocus()<CR>', { noremap = true, silent = true })


-- Automatically open nvim-tree when opening Neovim without arguments
vim.cmd([[
  autocmd VimEnter * if argc() == 0 | NvimTreeOpen | endif
]])




function ReloadConfig()
  -- Reload the main config
  dofile(vim.env.MYVIMRC)
  
  -- Reload Lazy.nvim managed plugins
  require('lazy').sync()

  print("Neovim configuration reloaded!")
end

-- Optionally, bind this to a key (e.g., <leader>rr)
vim.api.nvim_set_keymap('n', '<leader>rr', ':lua ReloadConfig()<CR>', { noremap = true, silent = true })

