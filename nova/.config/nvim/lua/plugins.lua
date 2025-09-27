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
    'MeanderingProgrammer/dashboard.nvim',
    event = 'VimEnter',
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
  },
  {
    'tzachar/highlight-undo.nvim',
  },
  {
    "lukas-reineke/headlines.nvim",
    dependencies = "nvim-treesitter/nvim-treesitter",
    config = true, -- or `opts = {}`
  },
  -- === Utility Plugins ===
  {
    'nvim-telescope/telescope.nvim',
    tag = '0.1.8',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-telescope/telescope-fzf-native.nvim',
      'nvim-telescope/telescope-file-browser.nvim',
      build = 'make'
    }
  },
  {
    'windwp/nvim-autopairs',
    event = "InsertEnter",
    config = true
  },
  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
    end
  },

  {
    "folke/trouble.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {},
    cmd = "Trouble",
  },

  {
    "epwalsh/obsidian.nvim",
    version = "*",
    lazy = true,
    ft = "markdown",
    ui = { enable = true },
    dependencies = { "nvim-lua/plenary.nvim" },
  },
  {
    'nvim-orgmode/orgmode',
    event = 'VeryLazy',
    ft = { 'org' },
    config = function()
      -- Setup orgmode
      require('orgmode').setup({
      })
    end,
  },
  -- === Development Plugins ===
  { "neovim/nvim-lspconfig" },
  {
    "williamboman/mason.nvim",
    build = ":MasonUpdate",
    config = true
  },
  { "williamboman/mason-lspconfig.nvim" },

  -- DAP
  -- { "mfussenegger/nvim-dap" },
  -- {
  --   "rcarriga/nvim-dap-ui",
  --   dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" }
  -- },
  -- { "theHamsta/nvim-dap-virtual-text" },
  -- { "mfussenegger/nvim-dap-python" },
  -- {
  --   "linux-cultist/venv-selector.nvim",
  --   config = function()
  --     require("venv-selector").setup {
  --       auto_refresh = true,
  --     }
  --   end,
  -- },

  -- Completion
  { "hrsh7th/nvim-cmp" },
  { "hrsh7th/cmp-nvim-lsp" },
  { "hrsh7th/cmp-buffer" },
  { "hrsh7th/cmp-path" },
  { "hrsh7th/cmp-nvim-lua" },
  { "hrsh7th/cmp-nvim-lsp-signature-help" },

  -- LSP UI
  {
    "nvimdev/lspsaga.nvim",
    event = "LspAttach",
    config = true,
  },

  -- Code formating
  { "stevearc/conform.nvim" },

  -- AVANTE AI
  -- {
  --   "yetone/avante.nvim",
  --   build = "make BUILD_FROM_SOURCE=true",
  --   event = "VeryLazy",
  --   version = false,
  --   opts = {
  --     provider = "gemini",
  --     providers = {
  --       gemini = {
  --         model = "gemini-2.5-flash",
  --       },
  --     },
  --   },
  --   dependencies = {
  --     "nvim-lua/plenary.nvim",
  --     "MunifTanjim/nui.nvim",
  --     "echasnovski/mini.pick",
  --     "hrsh7th/nvim-cmp",
  --     "ibhagwan/fzf-lua",
  --     "stevearc/dressing.nvim",
  --     "folke/snacks.nvim",
  --     "nvim-tree/nvim-web-devicons",
  --     "zbirenbaum/copilot.lua",
  --     {
  --       'MeanderingProgrammer/render-markdown.nvim',
  --       opts = {
  --         file_types = { "markdown", "Avante" },
  --       },
  --       ft = { "markdown", "Avante" },
  --     },
  --   },
  -- }
})
