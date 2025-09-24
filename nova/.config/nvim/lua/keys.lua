-- Keybindings with Which-Key
local vim = vim
local wk = require("which-key")

-- File Tree
wk.add {
  { "<leader>.", "<cmd>lua require('telescope').extensions.file_browser.file_browser({ path = vim.fn.expand('%:p:h'), select_buffer = true, hidden = true, follow_symlinks = true })<CR>", desc = "Toggle file explorer" },
}
-- wk.add {
--   { "<leader>O", ":NvimTreeToggle<CR>", desc = "Toggle file explorer" },
-- }

-- Tabs
wk.add {
  { "<C-t>", ":tabnew<CR>", desc = "New tab" },
}

-- Telescope
local builtin = require("telescope.builtin")
wk.add({
  {
    "<leader><space>",
    function()
      local ok = pcall(builtin.git_files, { show_untracked = true })
      if not ok then builtin.find_files({ previewer = true }) end
    end,
    desc = "Smart Find Files"
  },

  { "<leader>,",  function() builtin.buffers() end,  desc = "Switch Buffers" },

  {
    "<leader>ff",
    function()
      builtin.find_files({
        previewer = true,
        cwd = vim.fn.expand("%:p:h"),
        prompt_title = "Find Nearby Files"
      })
    end,
    desc = "Find Files (relative)"
  },

  {
    "<leader>fc",
    function()
      builtin.find_files({
        cwd = vim.fn.stdpath("config"),
        prompt_title = "Find Config Files",
        previewer = true
      })
    end,
    desc = "Find Config Files"
  },

  { "<leader>fr", function() builtin.oldfiles() end, desc = "Recent Files" },
})

-- Terminal
wk.add {
  { "<M-v>", ":ToggleTerm dir=%:p:h direction=vertical size=50<CR>",   desc = "Vertical terminal" },
  { "<M-d>", ":ToggleTerm dir=%:p:h direction=vertical size=50<CR>",   desc = "Vertical terminal" },
  { "<M-h>", ":ToggleTerm dir=%:p:h direction=horizontal size=10<CR>", desc = "Horizontal terminal" },
  { "<C-d>", ":ToggleTerm dir=%:p:h direction=float<CR>",              desc = "Floating terminal" },
}

-- Buffer Navigation
wk.add {
  { "<M-Right>", ":bnext<CR>", desc = "Next buffer" },
  { "<M-Left>",  ":bprev<CR>", desc = "Previous buffer" },
  { "<leader>q", ":bd<CR>",    desc = "Close buffer" },
}

-- Run File
wk.add {
  { "<leader>r", RunFile, desc = "Run current file" },
}

-- Open Specific Files
wk.add {
  { "<leader>wn", "<cmd>edit ~/.config/nvim/init.lua<cr>",      desc = "Open Neovim config" },
  { "<leader>ww", "<cmd>edit ~/Notes/index.md<cr>",             desc = "Open Notes" },
  { "<leader>hc", "<cmd>edit ~/.config/hypr/hyprland.conf<cr>", desc = "Open Hyprland Config" },
  { "<leader>hb", "<cmd>edit ~/.config/hypr/binds.conf<cr>",    desc = "Open Binds Config" },
}

-- Obsidian Keybindings
wk.add {
  { "<leader>os", ":ObsidianSearch<cr>", desc = "Obsidian Search" },
  { "<leader>on", ":ObsidianNew<cr>",    desc = "Obsidian New File" }
}

-- Navigation
vim.keymap.set({ 'n', 'v', 'i' }, '<C-h>', '^', { noremap = true })
vim.keymap.set({ 'n', 'v', 'i' }, '<C-l>', '$', { noremap = true })

-- Debug Keybindings
wk.add {
  { "<leader>d", group = "Debug" },

  -- MAIN DEBUG FUNCTIONS
  { "<leader>dd", SmartDebugPython, desc = "🧠 Smart Debug (Auto UV/Python)" },
  { "<leader>dv", DebugPythonUV, desc = "🚀 Force UV Debug" },
  { "<leader>dp", DebugPython, desc = "🐍 Force Regular Python Debug" },
  { "<leader>da", "<cmd>lua require('dap').run(require('dap').configurations.python[2])<CR>", desc = "Debug with Args" },

  -- Debug Actions
  { "<leader>ds", "<cmd>lua require('dap').continue()<CR>", desc = "Start/Continue" },
  { "<leader>db", "<cmd>lua require('dap').toggle_breakpoint()<CR>", desc = "Toggle Breakpoint" },
  { "<leader>dB", "<cmd>lua require('dap').set_breakpoint(vim.fn.input('Breakpoint condition: '))<CR>", desc = "Conditional Breakpoint" },
  { "<leader>dc", "<cmd>lua require('dap').run_last()<CR>", desc = "Run Last" },
  { "<leader>du", "<cmd>lua require('dapui').toggle()<CR>", desc = "Toggle UI" },
  { "<leader>do", "<cmd>lua require('dap').step_over()<CR>", desc = "Step Over" },
  { "<leader>di", "<cmd>lua require('dap').step_into()<CR>", desc = "Step Into" },
  { "<leader>dO", "<cmd>lua require('dap').step_out()<CR>", desc = "Step Out" },
  { "<leader>dr", "<cmd>lua require('dap').repl.open()<CR>", desc = "Open REPL" },
  { "<leader>dt", "<cmd>lua require('dap').terminate()<CR>", desc = "Terminate" },
  { "<leader>dh", "<cmd>lua require('dap.ui.widgets').hover()<CR>", desc = "Hover Variables" },
  { "<leader>dp", "<cmd>lua require('dap.ui.widgets').preview()<CR>", desc = "Preview" },
  { "<leader>df", "<cmd>lua local widgets=require('dap.ui.widgets');widgets.centered_float(widgets.frames)<CR>", desc = "Frames" },
  { "<leader>dS", "<cmd>lua local widgets=require('dap.ui.widgets');widgets.centered_float(widgets.scopes)<CR>", desc = "Scopes" },
  { "<leader>dC", "<cmd>lua require('dap').clear_breakpoints()<CR>", desc = "Clear All Breakpoints" },
  { "<leader>dR", "<cmd>lua require('dap').run_to_cursor()<CR>", desc = "Run to Cursor" },
  { "<leader>dd", DebugPython, desc = "Debug Python Method" },
}

-- Diagnostics
wk.register({
  x = {
    name = "Trouble",
    x = { "<cmd>Trouble diagnostics toggle<cr>", "Diagnostics" },
    X = { "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", "Buffer Diagnostics" },
    L = { "<cmd>Trouble loclist toggle<cr>", "Location List" },
    Q = { "<cmd>Trouble qflist toggle<cr>", "Quickfix List" },
    c = { Copy_diagnosics, "Copy current line diagnostics" },
    s = { Toggle_pyright_ignore, "Toggle # pyright: ignore on current line" }

  },

  c = {
    name = "Custom",
    s = { "<cmd>Trouble symbols toggle focus=false<cr>", "Symbols" },
    l = { "<cmd>Trouble lsp toggle focus=false win.position=right<cr>", "LSP List" },
  },
}, {
  prefix = "<leader>",
  mode = "n", -- 💡 This is the crucial fix
})


function Toggle_nvimtree()
  if vim.fn.bufname():match 'NvimTree_' then
    vim.cmd.wincmd 'p'          -- Switch to previous window (editor)
  else
    vim.cmd('NvimTreeFindFile') -- Open and focus on current file
  end
end

-- Set the keybinding
vim.keymap.set('n', '<leader>e', '<cmd>lua Toggle_nvimtree()<CR>',
  { desc = 'Toggle focus between editor and explorer' })
