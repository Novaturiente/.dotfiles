local vim = vim

-- Treesitter config
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

-- Configure Undo history
require('highlight-undo').setup({
  duration = 600,
  ignored_filetypes = { "neo-tree", "fugitive", "TelescopePrompt", "mason", "lazy", "dashboard" },
})

-- Noice configuration
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

-- Debug config
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

-- Notify config
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

-- Telescope configuration
require('telescope').setup({
  defaults = {
    sorting_strategy = "ascending",
    layout_config = {
      prompt_position = "top",
    },
    file_ignore_patterns = { ".git/", "node_modules" },
    winblend = 0,
    color_devicons = true,
    dynamic_preview_title = true,
    preview = {
      timeout = 500,
    },
    path_display = { "smart" }, -- shortens long paths
  },
  pickers = {
    find_files = {
      theme = "dropdown", -- or "ivy", "cursor"
      previewer = true,
    },
    buffers = {
      theme = "dropdown",
      previewer = false,
      sort_mru = true,
    },
    oldfiles = {
      theme = "dropdown",
      previewer = false,
    }
  },
  extensions = {
    fzf = {
      fuzzy = true,
      override_generic_sorter = true,
      override_file_sorter = true,
      case_mode = "smart_case",
    }
  },
})

-- Load the FZF native extension
require('telescope').load_extension('fzf')

-- Set colorscheme
local themes = {
  "tokyonight-night",
  "rose-pine",
  "github_dark_default",
  "github_dark_high_contrast",
}
local config_path = vim.fn.stdpath("config") .. "/.last_colorscheme"
local function set_colorscheme(scheme)
  vim.cmd("colorscheme " .. scheme)
  -- Save to file
  local f = io.open(config_path, "w")
  if f then
    f:write(scheme)
    f:close()
  end
end
local function pick_colorscheme()
  require('telescope.pickers').new({}, {
    prompt_title = 'Select Colorscheme',
    finder = require('telescope.finders').new_table {
      results = themes,
    },
    sorter = require('telescope.config').values.generic_sorter({}),
    layout_strategy = 'center',
    layout_config = {
      width = 0.4,
      height = 0.3,
    },
    attach_mappings = function(_, map)
      map('i', '<CR>', function(prompt_bufnr)
        local selection = require('telescope.actions.state').get_selected_entry()
        require('telescope.actions').close(prompt_bufnr)
        set_colorscheme(selection[1])
      end)
      return true
    end,
  }):find()
end
local f = io.open(config_path, "r")
if f then
  local scheme = f:read("*l")
  f:close()
  if scheme then
    vim.cmd("colorscheme " .. scheme)
  end
end
vim.keymap.set("n", "<leader>ct", pick_colorscheme, { desc = "Pick Colorscheme" })

-- Dashboard configuration
local arts = require('ascii_arts')
math.randomseed(vim.loop.hrtime())
local header = arts[math.random(#arts)]
require('dashboard').setup({
  header = header,
  date_format = '%Y-%m-%d %H:%M:%S',
  directories = {
    '~/.dotfiles/novarch',
    '~/.config',
    '~/Notes',
    '~/develop',
  },
})

-- Lualine configuration
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
