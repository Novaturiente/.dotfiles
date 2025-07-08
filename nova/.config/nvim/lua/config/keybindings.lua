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
  {"<leader>ww", "<cmd>edit ~/develop/Notes/index.md<cr>", desc = "Open Notes"},
  {"<leader>hc", "<cmd>edit ~/.config/hypr/hyprland.conf<cr>", desc = "Open Notes"},
  {"<leader>hb", "<cmd>edit ~/.config/hypr/binds.conf<cr>", desc = "Open Notes"}
}

-- Obsidian keybindings
wk.add{
  {"<leader>os", ":ObsidianSearch<cr>", desc = "Obsidian Search"},
  {"<leader>on", ":ObsidianNew<cr>", desc = "Obsidian new file"}
}

-- Navigation
vim.keymap.set({'n', 'v', 'i'}, '<C-h>', '^', { noremap = true })
vim.keymap.set({'n', 'v', 'i'}, '<C-l>', '$', { noremap = true })

-- Debug keybindings (REPLACE the existing debug section)
wk.add{
  { "<leader>d", group = "Debug" },
  -- MAIN DEBUG FUNCTIONS
  { "<leader>dd", SmartDebugPython, desc = "🧠 Smart Debug (Auto UV/Python)" },
  { "<leader>dv", DebugPythonUV, desc = "🚀 Force UV Debug" },
  { "<leader>dp", DebugPython, desc = "🐍 Force Regular Python Debug" },
  { "<leader>da", "<cmd>lua require('dap').run(require('dap').configurations.python[2])<CR>", desc = "Debug with Args" },

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
