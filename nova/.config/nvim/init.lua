-- General Settings
vim.wo.number = true                  -- Enable line numbers
vim.g.mapleader = ' '                 -- Set leader key to space
vim.opt.clipboard = 'unnamedplus'     -- Use system clipboard
vim.o.mouse = 'a'                     -- Enable mouse support
vim.o.foldmethod = "manual"           -- Manual folding
vim.o.foldenable = true               -- Enable folding

-- Prevent errors when plugins are not yet installed
local function safe_require(module)
  local success, result = pcall(require, module)
  if not success then
    vim.notify("Module " .. module .. " not found. Run :Lazy sync to install missing plugins.", vim.log.levels.WARN)
    return nil
  end
  return result
end

-- Set a timeout for LSP initialization to prevent hanging
vim.lsp.set_log_level("error") -- Reduce log verbosity

-- Make sure filesystem notifications don't cause errors
vim.opt.fsync = false

-- Fix potential treesitter errors
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
-- 🔌 PLUGIN SETUP (Managed via Lazy.nvim)
-- This section includes plugin configurations for UI, LSP,
-- completions, terminal integration, file explorer, and more.
-- ========================================================
require('lazy').setup({
  -- Theme plugin: GitHub Dark theme
  {
    'projekt0n/github-nvim-theme',
    name = 'github-theme',
    lazy = false,
    priority = 1000, -- Load theme early
    config = function()
      require('github-theme').setup({})
      vim.cmd('colorscheme github_dark')
    end,
  },
  
  -- File Explorer: Tree-style file browser
  {
    'nvim-tree/nvim-tree.lua',
    dependencies = { 'nvim-tree/nvim-web-devicons' }, -- Icons for file types
    config = function()
      require('nvim-tree').setup {}
    end
  },

  -- Rust-specific plugins
  {
    'simrat39/rust-tools.nvim',       -- Enhanced Rust development tools
    dependencies = {
      'neovim/nvim-lspconfig',
      'nvim-lua/plenary.nvim',
    },
    config = function()
      local rt = require("rust-tools")
      rt.setup({
        server = {
          on_attach = function(_, bufnr)
            -- Hover actions
            vim.keymap.set("n", "<C-space>", rt.hover_actions.hover_actions, { buffer = bufnr })
            -- Code action groups
            vim.keymap.set("n", "<Leader>a", rt.code_action_group.code_action_group, { buffer = bufnr })
            -- Runnables
            vim.keymap.set("n", "<leader>rr", rt.runnables.runnables, { buffer = bufnr })
            -- Expand macros
            vim.keymap.set("n", "<leader>em", rt.expand_macro.expand_macro, { buffer = bufnr })
            -- Move item up/down
            vim.keymap.set("n", "<leader>mj", rt.move_item.move_item_down, { buffer = bufnr })
            vim.keymap.set("n", "<leader>mk", rt.move_item.move_item_up, { buffer = bufnr })
          end,
          settings = {
            ["rust-analyzer"] = {
              checkOnSave = {
                command = "clippy", -- Use clippy for more thorough checking
              },
              cargo = {
                allFeatures = true,
                loadOutDirsFromCheck = true,
              },
              procMacro = {
                enable = true,
              },
            }
          }
        },
      })
    end
  },

  -- Enhanced Rust crate management
  {
    'saecki/crates.nvim',             -- Handles Cargo.toml dependencies
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
      require('crates').setup({
        smart_insert = true,
        autoload = true,
        autoupdate = true,
        popup = {
          border = "rounded",
        },
        text = {
          loading = "Loading...",
          version = "  %s",
          prerelease = " %s",
          yanked = " %s yanked",
          nomatch = "No matching versions",
          upgrade = "  %s",
          error = "Error fetching crate",
        },
      })
      
      -- Crates key mappings
      vim.api.nvim_set_keymap("n", "<leader>ct", ":lua require('crates').toggle()<CR>", { noremap = true, silent = true })
      vim.api.nvim_set_keymap("n", "<leader>cr", ":lua require('crates').reload()<CR>", { noremap = true, silent = true })
      vim.api.nvim_set_keymap("n", "<leader>cv", ":lua require('crates').show_versions_popup()<CR>", { noremap = true, silent = true })
      vim.api.nvim_set_keymap("n", "<leader>cf", ":lua require('crates').show_features_popup()<CR>", { noremap = true, silent = true })
    end,
  },

  -- Autocompletion engine
  {
    'hrsh7th/nvim-cmp',               -- Main completion plugin
    dependencies = {
      'hrsh7th/cmp-nvim-lsp',         -- LSP source for nvim-cmp
      'hrsh7th/cmp-buffer',           -- Buffer source for completions
      'hrsh7th/cmp-path',             -- Path completions
      'hrsh7th/cmp-cmdline',          -- Command line completions
      'hrsh7th/cmp-nvim-lsp-signature-help', -- Function signature help
      'hrsh7th/cmp-vsnip',            -- Snippet completion source
      'hrsh7th/vim-vsnip',            -- Snippet engine
    },
    config = function()
      local cmp = require('cmp')
      cmp.setup({
        snippet = {
          expand = function(args)
            vim.fn["vsnip#anonymous"](args.body)
          end,
        },
        completion = { completeopt = 'menu,menuone,noinsert' },
        window = {
          completion = cmp.config.window.bordered(),
          documentation = cmp.config.window.bordered(),
        },
        mapping = {
          ['<C-k>'] = cmp.mapping.select_prev_item(),
          ['<C-j>'] = cmp.mapping.select_next_item(),
          ['<C-Space>'] = cmp.mapping.complete(),
          ['<C-b>'] = cmp.mapping.scroll_docs(-4),
          ['<C-f>'] = cmp.mapping.scroll_docs(4),
          ['<C-e>'] = cmp.mapping.abort(),
          ['<Tab>'] = cmp.mapping.confirm({ select = true }),
        },
        sources = {
          { name = 'nvim_lsp' },
          { name = 'vsnip' },
          { name = 'crates' },
          { name = 'buffer' },
          { name = 'path' },
        },
      })
    end,
  },
  
  -- Terminal integration
  {'akinsho/toggleterm.nvim', version = "*", config = true}, -- Toggleable terminal
  
  -- Syntax highlighting with tree-sitter
  {
    'nvim-treesitter/nvim-treesitter',
    run = ':TSUpdate',
    config = function()
      require('nvim-treesitter.configs').setup {
        -- Add Python to the ensure_installed list
        ensure_installed = { "rust", "toml", "python", "lua", "vim", "vimdoc", "query" },
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
  
  -- Status line plugin
  { 'nvim-lualine/lualine.nvim' },
  
  -- Notification system
  {'rcarriga/nvim-notify'},
  
  -- Enhanced command-line experience
  {'gelguy/wilder.nvim'},
  
  -- UI improvements for messages, cmdline & popupmenu
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    opts = {},
    dependencies = {
      "MunifTanjim/nui.nvim",
      "rcarriga/nvim-notify",
    }
  },
  
  -- Fuzzy finder
  {
    'nvim-telescope/telescope.nvim', 
    tag = '0.1.8',
    dependencies = { 'nvim-lua/plenary.nvim' }
  },
  
  -- Auto pair brackets, quotes, etc.
  {
    'windwp/nvim-autopairs',
    event = "InsertEnter",
    config = true
  },
  
  -- LSP configuration
  {
    'neovim/nvim-lspconfig',
    config = function()
      -- LSP servers configuration besides rust-tools (handled separately)
      local lspconfig = require('lspconfig')
      
      -- Python setup with enhanced configuration
      lspconfig.pyright.setup {
        settings = {
          python = {
            analysis = {
              autoSearchPaths = true,
              diagnosticMode = "workspace",
              useLibraryCodeForTypes = true,
              typeCheckingMode = "basic", -- Can be "off", "basic", or "strict"
            }
          }
        }
      }
      
      -- Add Python-specific debug adapter
      lspconfig.debugpy.setup {
        -- If needed for advanced debugging workflows
      }
      
      -- TypeScript setup
      lspconfig.tsserver.setup {}
      
      -- Global mappings for LSP
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('UserLspConfig', {}),
        callback = function(ev)
          local opts = { buffer = ev.buf }
          vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
          vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
          vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
          vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
          vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
          vim.keymap.set('n', '<leader>D', vim.lsp.buf.type_definition, opts)
          vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
          vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)
          vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
          vim.keymap.set('n', '<leader>f', function()
            vim.lsp.buf.format { async = true }
          end, opts)
        end,
      })
    end
  },
  
  -- Status line with Git integration
  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      require('lualine').setup {
        options = {
          theme = 'github_dark',
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

  -- Better diagnostic display
  {
    "folke/trouble.nvim",             -- Enhanced diagnostics viewer
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("trouble").setup {
        position = "bottom",
        icons = true,
        auto_open = false,
        auto_close = true,
        use_diagnostic_signs = true
      }
      
      -- Trouble keymaps
      vim.api.nvim_set_keymap("n", "<leader>xx", "<cmd>TroubleToggle<cr>", { silent = true, noremap = true })
      vim.api.nvim_set_keymap("n", "<leader>xw", "<cmd>TroubleToggle workspace_diagnostics<cr>", { silent = true, noremap = true })
      vim.api.nvim_set_keymap("n", "<leader>xd", "<cmd>TroubleToggle document_diagnostics<cr>", { silent = true, noremap = true })
      vim.api.nvim_set_keymap("n", "<leader>xl", "<cmd>TroubleToggle loclist<cr>", { silent = true, noremap = true })
      vim.api.nvim_set_keymap("n", "<leader>xq", "<cmd>TroubleToggle quickfix<cr>", { silent = true, noremap = true })
    end
  },
  
  -- Python specific plugins
  {
    "mfussenegger/nvim-dap",          -- Debug Adapter Protocol client
    dependencies = {
      "mfussenegger/nvim-dap-python", -- Python DAP integration
      "rcarriga/nvim-dap-ui",         -- UI for debugging
    },
    config = function()
      -- Load the Python DAP extension
      local dap_python = require('dap-python')
      -- Try to find python in the current environment or fall back to system python
      local python_path = vim.fn.exepath('python3') or vim.fn.exepath('python') or '/usr/bin/python3'
      dap_python.setup(python_path)
      
      -- Add configurations for Django, Flask, etc.
      dap_python.test_runner = 'pytest'
      
      -- Set up basic keymaps for debugging
      vim.api.nvim_set_keymap("n", "<leader>db", ":lua require'dap'.toggle_breakpoint()<CR>", { noremap = true, silent = true })
      vim.api.nvim_set_keymap("n", "<leader>dc", ":lua require'dap'.continue()<CR>", { noremap = true, silent = true })
      vim.api.nvim_set_keymap("n", "<leader>do", ":lua require'dap'.step_over()<CR>", { noremap = true, silent = true })
      vim.api.nvim_set_keymap("n", "<leader>di", ":lua require'dap'.step_into()<CR>", { noremap = true, silent = true })
      vim.api.nvim_set_keymap("n", "<leader>dt", ":lua require'dap-python'.test_method()<CR>", { noremap = true, silent = true })
    end
  },
  
  -- Python code formatting
  {
    "psf/black",                      -- Black formatter for Python
    ft = "python",                    -- Load only for Python files
  },
  
  -- Python type checking and imports
  {
    "stsewd/isort.nvim",              -- Sort Python imports
    ft = "python",
    config = function()
      require('isort').setup()
    end
  },
  
  -- Python docstring generation
  {
    "danymat/neogen",                 -- Generate docstrings
    dependencies = "nvim-treesitter/nvim-treesitter",
    config = function()
      require('neogen').setup({
        enabled = true,
        languages = {
          python = {
            template = {
              annotation_convention = "google_docstrings" -- or numpydoc, reST
            }
          },
        }
      })
      -- Keybinding for docstring generation
      vim.api.nvim_set_keymap("n", "<leader>doc", ":lua require('neogen').generate()<CR>", { noremap = true, silent = true })
    end
  },
})

-- ====================
-- 🌳 UI and UX Enhancements
-- ====================

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

-- Set up diagnostic symbols
local signs = { Error = " ", Warn = " ", Hint = " ", Info = " " }
for type, icon in pairs(signs) do
  local hl = "DiagnosticSign" .. type
  vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
end

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
vim.api.nvim_set_keymap('n', '<leader>rc', ':lua ReloadConfig()<CR>', { noremap = true, silent = true })

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

-- Enhanced run command for multiple languages
-- Define this globally once
local Terminal = require('toggleterm.terminal').Terminal

-- Single persistent terminal instance
local runner = nil

function RunFile()
  -- Create terminal only once
  if not runner then
    runner = Terminal:new({
      direction = "float",
      close_on_exit = true,
      hidden = true,
    })
  end

  local file = vim.fn.expand("%:p")
  local ext = vim.fn.expand("%:e")

  -- Open if it's not open yet
  if not runner:is_open() then
    runner:toggle()
  end

  -- Determine command based on file extension
  local cmd = ""
  if ext == "py" then
    -- Use virtual environments if available
    local venv = vim.fn.finddir('venv', '.;')
    local pyenv = vim.fn.finddir('.venv', '.;')
    local poetry = vim.fn.findfile('poetry.lock', '.;')
    
    if venv ~= "" then
      cmd = "source " .. venv .. "/bin/activate && python " .. file
    elseif pyenv ~= "" then
      cmd = "source " .. pyenv .. "/bin/activate && python " .. file
    elseif poetry ~= "" then
      cmd = "poetry run python " .. file
    else
      cmd = "python3 " .. file
    end
  elseif ext == "rs" then
    -- For Rust, use cargo run with better error formatting
    local cargo_toml = vim.fn.findfile("Cargo.toml", ".;")
    if cargo_toml ~= "" then
      cmd = "RUST_BACKTRACE=1 cargo run"
    else
      cmd = "rustc " .. file .. " && " .. vim.fn.fnamemodify(file, ":r")
    end
  else
    print("Unsupported file type: " .. ext)
    return
  end

  -- Send the command to terminal
  runner:send(cmd)
end

-- Run with custom args
function RunWithArgs()
  -- Prompt for arguments
  local args = vim.fn.input("Arguments: ")
  
  -- Create terminal only once
  if not runner then
    runner = Terminal:new({
      direction = "float",
      close_on_exit = true,
      hidden = true,
    })
  end

  local ext = vim.fn.expand("%:e")
  local file = vim.fn.expand("%:p")

  -- Open if it's not open yet
  if not runner:is_open() then
    runner:toggle()
  end

  -- Run with args
  local cmd = ""
  if ext == "py" then
    -- Check for Python virtual environments
    local venv = vim.fn.finddir('venv', '.;')
    local pyenv = vim.fn.finddir('.venv', '.;')
    local poetry = vim.fn.findfile('poetry.lock', '.;')
    
    if venv ~= "" then
      cmd = "source " .. venv .. "/bin/activate && python " .. file .. " " .. args
    elseif pyenv ~= "" then
      cmd = "source " .. pyenv .. "/bin/activate && python " .. file .. " " .. args
    elseif poetry ~= "" then
      cmd = "poetry run python " .. file .. " " .. args
    else
      cmd = "python3 " .. file .. " " .. args
    end
  elseif ext == "rs" then
    local cargo_toml = vim.fn.findfile("Cargo.toml", ".;")
    if cargo_toml ~= "" then
      cmd = "RUST_BACKTRACE=1 cargo run -- " .. args
    else
      cmd = "rustc " .. file .. " && " .. vim.fn.fnamemodify(file, ":r") .. " " .. args
    end
  else
    print("Unsupported file type: " .. ext)
    return
  end

  -- Send the command to terminal
  runner:send(cmd)
end

-- Cargo commands
function CargoCheck()
  if not runner then
    runner = Terminal:new({
      direction = "float",
      close_on_exit = true,
      hidden = true,
    })
  end
  
  if not runner:is_open() then
    runner:toggle()
  end
  
  runner:send("cargo check")
end

function CargoTest()
  if not runner then
    runner = Terminal:new({
      direction = "float",
      close_on_exit = true,
      hidden = true,
    })
  end
  
  if not runner:is_open() then
    runner:toggle()
  end
  
  runner:send("cargo test")
end

function CargoClippy()
  if not runner then
    runner = Terminal:new({
      direction = "float",
      close_on_exit = true,
      hidden = true,
    })
  end
  
  if not runner:is_open() then
    runner:toggle()
  end
  
  runner:send("cargo clippy")
end

-- Python-specific commands
function PythonTest()
  if not runner then
    runner = Terminal:new({
      direction = "float",
      close_on_exit = true,
      hidden = true,
    })
  end
  
  if not runner:is_open() then
    runner:toggle()
  end
  
  -- Check for pytest, unittest, or Django test
  local pytest = vim.fn.findfile('pytest.ini', '.;')
  local djangoManage = vim.fn.findfile('manage.py', '.;')
  
  if pytest ~= "" then
    runner:send("pytest")
  elseif djangoManage ~= "" then
    runner:send("python manage.py test")
  else
    -- Fall back to unittest discover
    runner:send("python -m unittest discover")
  end
end

function PythonLint()
  if not runner then
    runner = Terminal:new({
      direction = "float",
      close_on_exit = true,
      hidden = true,
    })
  end
  
  if not runner:is_open() then
    runner:toggle()
  end
  
  -- Use flake8 for linting
  runner:send("flake8 .")
end

function PythonFormat()
  if not runner then
    runner = Terminal:new({
      direction = "float",
      close_on_exit = true,
      hidden = true,
    })
  end
  
  if not runner:is_open() then
    runner:toggle()
  end
  
  -- Format with black and isort
  local file = vim.fn.expand("%:p")
  runner:send("black " .. file .. " && isort " .. file)
end

-- Rust-specific keymaps
vim.api.nvim_set_keymap("n", "<leader>r", ":lua RunFile()<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>ra", ":lua RunWithArgs()<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>cc", ":lua CargoCheck()<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>ct", ":lua CargoTest()<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>cp", ":lua CargoClippy()<CR>", { noremap = true, silent = true })

-- Python-specific keymaps
vim.api.nvim_set_keymap("n", "<leader>pt", ":lua PythonTest()<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>pl", ":lua PythonLint()<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>pf", ":lua PythonFormat()<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<leader>pi", ":lua require('isort').format()<CR>", { noremap = true, silent = true })

-- File-specific configurations
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = { "*.rs" },
  callback = function()
    -- Set up formatoptions for Rust files
    vim.opt_local.formatoptions = vim.opt_local.formatoptions
      - "o"  -- Don't continue comments when pressing 'o'
      + "r"  -- Continue comments after hitting <Enter>
      + "c"  -- Auto-wrap comments using textwidth
      + "q"  -- Allow formatting comments with gq
  end,
})

-- Python-specific settings
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = { "*.py" },
  callback = function()
    -- PEP 8 indentation
    vim.opt_local.expandtab = true
    vim.opt_local.shiftwidth = 4
    vim.opt_local.softtabstop = 4
    vim.opt_local.tabstop = 4
    
    -- Line length marker
    vim.opt_local.colorcolumn = "88"  -- Black's default line length
    
    -- Python formatting options
    vim.opt_local.formatoptions = vim.opt_
    -- Python formatting options
    vim.opt_local.formatoptions = vim.opt_local.formatoptions
      - "o"  -- Don't continue comments when pressing 'o'
      + "r"  -- Continue comments after hitting <Enter>
      + "c"  -- Auto-wrap comments using textwidth
      + "q"  -- Allow formatting comments with gq
  end,
})

require("keybindings.cheatsheet")
vim.api.nvim_set_keymap("n", "<leader>cs", ":lua require'keybindings.cheatsheet'.show_cheat_sheet()<CR>", { noremap = true, silent = true })
