local vim = vim

-- Run current file
local Terminal = require("toggleterm.terminal").Terminal

function RunFile()
  local ext = vim.fn.expand('%:e')
  local file = vim.fn.expand('%')
  local cmd = nil

  if ext == "py" then
    cmd = 'zsh -c "uv run ' .. file .. '; zsh"'
    -- Added C/C++ run commands
  elseif ext == "c" then
    cmd = string.format('zsh -c "gcc -g %s -o %s && ./%s; zsh"', file, vim.fn.expand('%:r'), vim.fn.expand('%:r'))
  elseif ext == "cpp" then
    cmd = string.format('zsh -c "g++ -g %s -o %s && ./%s; zsh"', file, vim.fn.expand('%:r'), vim.fn.expand('%:r'))
  elseif ext == "rs" then
    cmd = 'zsh -c "cargo run; zsh"'
  else
    print("No run command for extension: " .. ext)
    return
  end

  local term = Terminal:new({
    cmd = cmd,
    direction = "float",
    close_on_exit = true,
    hidden = true
  })
  term:toggle()
end

-- obsidian configurations
require('obsidian').setup({
  workspaces = {
    {
      name = "notes",
      path = "~/Notes/",
    },
  },

  note_id_func = function(title)
    return title and title:gsub(" ", "_"):lower() or "untitled"
  end,

  follow_url_func = function(url)
    vim.fn.jobstart({ "xdg-open", url })
  end,

  ui = { enable = true },
})

-- Copy diagnostics
function Copy_diagnosics()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  vim.fn.setreg("+", {}, "V")
  local msgs = {}
  for _, d in ipairs(vim.diagnostic.get(0, { lnum = line - 1 })) do
    local m = d.message
    table.insert(msgs, m)
    vim.fn.setreg("+", vim.fn.getreg("+") .. m .. "\n", "V")
  end

  if #msgs == 0 then
    vim.notify("No diagnostics on line " .. line, vim.log.levels.ERROR)
    return nil
  end

  local txt = table.concat(msgs, "\n")
  vim.notify("Diagnostics from line " .. line .. " copied to clipboard.\n\n" .. txt, vim.log.levels.INFO)
  return txt
end

-- Toggle pyright
function Toggle_pyright_ignore()
  local bufnr = vim.api.nvim_get_current_buf()
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]

  local new_line = line:gsub("%s+$", "") .. " # pyright: ignore"
  vim.api.nvim_buf_set_lines(bufnr, row, row + 1, false, { new_line })
  vim.notify("Appended pyright ignore comment", vim.log.levels.INFO)
end
