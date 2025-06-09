-- ========================================================
-- 🗝️ KEYBINDINGS (Updated to new which-key spec)
-- ========================================================

local wk = require("which-key")

-- File Tree
wk.register({
  ["<leader>o"] = { ":NvimTreeToggle<CR>", "Toggle file explorer" },
})

-- Tabs
wk.register({
  ["<C-t>"] = { ":tabnew<CR>", "New tab" },
})

-- Telescope
local builtin = require('telescope.builtin')
wk.register({
  ["<leader>fg"] = { builtin.live_grep, "Live grep" },
  ["<leader>fb"] = { builtin.buffers, "Find buffers" },
  ["<leader>fh"] = { builtin.help_tags, "Help tags" },
})

-- Terminal
wk.register({
  ["<M-v>"] = { ":ToggleTerm direction=vertical size=50<CR>", "Vertical terminal" },
  ["<M-d>"] = { ":ToggleTerm direction=vertical size=50<CR>", "Vertical terminal" },
  ["<M-h>"] = { ":ToggleTerm direction=horizontal size=10<CR>", "Horizontal terminal" },
  ["<C-d>"] = { ":ToggleTerm direction=float<CR>", "Floating terminal" },
})

-- Buffer navigation
wk.register({
  ["<M-Right>"] = { ":bnext<CR>", "Next buffer" },
  ["<M-Left>"] = { ":bprev<CR>", "Previous buffer" },
})

-- Run file
wk.register({
  ["<leader>r"] = { _G.RunFile, "Run current file" },
})

-- Reload config
wk.register({
  ["<leader>rc"] = { _G.ReloadConfig, "Reload config" },
})

-- Diagnostics
wk.register({
  ["<leader>cc"] = {
    function()
      local diagnostics = vim.diagnostic.get(0, { lnum = vim.api.nvim_win_get_cursor(0)[1] - 1 })
      if vim.tbl_isempty(diagnostics) then
        print("No diagnostics to copy")
        return
      end
      local lines = {}
      for _, d in ipairs(diagnostics) do
        table.insert(lines, d.message)
      end
      local text = table.concat(lines, "\n")
      vim.fn.setreg('+', text)
      vim.notify("Copied diagnostic to clipboard", vim.log.levels.INFO)
    end,
    "Copy diagnostic to clipboard"
  },
  ["<leader>cx"] = {
    function()
      local line = vim.api.nvim_get_current_line()
      if not line:find("# type: ignore") then
        vim.api.nvim_set_current_line(line .. "  # type: ignore")
        vim.notify("Added '# type: ignore' to suppress Pyright warning", vim.log.levels.INFO)
      else
        vim.notify("'# type: ignore' already present", vim.log.levels.WARN)
      end
    end,
    "Suppress Pyright error"
  },
})

-- DAP keybindings
wk.register({
  ["<leader>d"] = { name = "Debug" },
  ["<leader>db"] = { function() require('dap').toggle_breakpoint() end, "Toggle breakpoint" },
  ["<leader>dc"] = { function() require('dap').continue() end, "Continue" },
  ["<leader>di"] = { function() require('dap').step_into() end, "Step into" },
  ["<leader>do"] = { function() require('dap').step_over() end, "Step over" },
  ["<leader>du"] = { function() require('dap').step_out() end, "Step out" },
  ["<leader>dr"] = { function() require('dap').repl.open() end, "Open REPL" },
  ["<leader>dl"] = { function() require('dap').run_last() end, "Run last" },
  ["<leader>dt"] = { function() require('dap-go').debug_test() end, "Debug test (Go)" },
})
