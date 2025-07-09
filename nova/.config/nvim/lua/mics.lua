-- Run current file
local Terminal = require("toggleterm.terminal").Terminal

function RunFile()
  local ext = vim.fn.expand('%:e')
  local file = vim.fn.expand('%')
  local cmd = nil

  if ext == "py" then
    cmd = 'fish -c "uv run ' .. file .. '; fish"'
  -- Added C/C++ run commands
  elseif ext == "c" then
    cmd = string.format('fish -c "gcc -g %s -o %s && ./%s; fish"', file, vim.fn.expand('%:r'), vim.fn.expand('%:r'))
  elseif ext == "cpp" then
    cmd = string.format('fish -c "g++ -g %s -o %s && ./%s; fish"', file, vim.fn.expand('%:r'), vim.fn.expand('%:r'))
  elseif ext == "rs" then
  cmd = 'fish -c "cargo run; fish"'
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
