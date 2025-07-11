local vim = vim

return require('lazy').setup({
  -- == THEME ==
  {
    "folke/tokyonight.nvim",
    name = 'tokyonight',
    lazy = false,
    priority = 1000,
  },
  {
    "rose-pine/neovim",
    name = "rose-pine",
    lazy = false,
    priority = 1000
  },
  { 'projekt0n/github-nvim-theme', name = 'github-theme' },

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
  { 'rcarriga/nvim-notify' },
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    opts = {},
    dependencies = {
      "MunifTanjim/nui.nvim",
      "rcarriga/nvim-notify",
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
  { 'akinsho/toggleterm.nvim',         version = "*", config = true },
  { 'liangxianzhe/floating-input.nvim' },

  -- === Syntax Highlighting & Text Objects ===
  {
    'nvim-treesitter/nvim-treesitter',
    run = ':TSUpdate',
    config = function()
      require('nvim-treesitter.configs').setup {
        ensure_installed = { "lua", "vim", "vimdoc", "query", "jsonc", "python", "c", "cpp", "rust" },
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
    },
  },
  -- === Utility Plugins ===
  {
    'nvim-telescope/telescope.nvim',
    tag = '0.1.8',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-telescope/telescope-fzf-native.nvim',
      build = 'make'
    }
  },
  {
    'windwp/nvim-autopairs',
    event = "InsertEnter",
    config = true
  },
  {
    "kylechui/nvim-surround",
    version = "^3.0.0",
    event = "VeryLazy",
    config = function()
      require("nvim-surround").setup({})
    end
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
          lualine_b = { 'branch', 'diff', 'diagnostics' },
          lualine_c = { { 'filename', path = 1 } },
        }
      }
    end
  },

  {
    "folke/trouble.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {},
    cmd = "Trouble",
    keys = {
      { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>",                        desc = "Diagnostics (Trouble)" },
      { "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>",           desc = "Buffer Diagnostics (Trouble)" },
      { "<leader>cs", "<cmd>Trouble symbols toggle focus=false<cr>",                desc = "Symbols (Trouble)" },
      { "<leader>cl", "<cmd>Trouble lsp toggle focus=false win.position=right<cr>", desc = "LSP Definitions / references / ..." },
      { "<leader>xL", "<cmd>Trouble loclist toggle<cr>",                            desc = "Location List (Trouble)" },
      { "<leader>xQ", "<cmd>Trouble qflist toggle<cr>",                             desc = "Quickfix List (Trouble)" },
    },
  },

  {
    "epwalsh/obsidian.nvim",
    version = "*",
    lazy = true,
    ft = "markdown",
    ui = { enable = true },
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {
      workspaces = {
        { name = "notes", path = "~/develop/Notes/" },
      },
      follow_url_func = function(url)
        vim.fn.jobstart({ "xdg-open", url })
      end,
    },
  },

  -- === Development Plugins ===
  { "neovim/nvim-lspconfig" },
  { "williamboman/mason.nvim",            build = ":MasonUpdate",                                             config = true },
  { "williamboman/mason-lspconfig.nvim" },

  -- DAP
  { "mfussenegger/nvim-dap" },
  { "rcarriga/nvim-dap-ui",               dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" } },
  { "theHamsta/nvim-dap-virtual-text" },
  { "mfussenegger/nvim-dap-python" },

  -- Completion
  { "hrsh7th/nvim-cmp" },
  { "hrsh7th/cmp-nvim-lsp" },
  { "hrsh7th/cmp-buffer" },
  { "hrsh7th/cmp-path" },
  { "hrsh7th/cmp-nvim-lua" },
  { "hrsh7th/cmp-nvim-lsp-signature-help" },
  { "L3MON4D3/LuaSnip" },
  {
    "saadparwaiz1/cmp_luasnip",
    dependencies = { "rafamadriz/friendly-snippets" },
  },

  -- LSP UI
  {
    "nvimdev/lspsaga.nvim",
    event = "LspAttach",
    config = true,
  },
})
