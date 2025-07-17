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
