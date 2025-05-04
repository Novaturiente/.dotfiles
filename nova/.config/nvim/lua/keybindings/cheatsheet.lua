-- ~/.config/nvim/lua/keybindings/cheatsheet.lua

local M = {}
local win_id = nil

function M.show_cheat_sheet()
  if win_id and vim.api.nvim_win_is_valid(win_id) then
    vim.api.nvim_win_close(win_id, true)
    win_id = nil
    return
  end
  local cheatsheet = {
    "🗺️ Neovim Cheat Sheet",
    "======================",
    "",
    "📂 File Navigation",
    "  <leader>e     - Toggle file explorer",
    "  <leader>ff    - Find files",
    "  <leader>fg    - Live grep",
    "  <leader>fb    - Browse buffers",
    "  <leader>fh    - Help tags",
    "",
    "📑 Tab Management",
    "  <C-t>         - New tab",
    "  <C-Tab>       - Next tab",
    "  <C-S-Tab>     - Previous tab",
    "",
    "🖥️ Terminal",
    "  <M-v>/<C-d>   - Vertical terminal",
    "  <M-h>         - Horizontal terminal",
    "  <M-d>         - Floating terminal",
    "  <M-Right>     - Toggle terminal focus",
    "  <M-Left>      - Toggle NvimTree focus",
    "  <M-Down>      - Focus back to editor",
    "",
    "🔧 LSP",
    "  gD            - Go to declaration",
    "  gd            - Go to definition",
    "  K             - Hover information",
    "  gi            - Go to implementation",
    "  <C-k>         - Signature help",
    "  <leader>D     - Type definition",
    "  <leader>rn    - Rename symbol",
    "  <leader>ca    - Code actions",
    "  gr            - Find references",
    "  <leader>f     - Format code",
    "",
    "🔍 Diagnostics",
    "  <leader>xx    - Toggle trouble",
    "  <leader>xw    - Workspace diagnostics",
    "  <leader>xd    - Document diagnostics",
    "  <leader>xl    - Location list",
    "  <leader>xq    - Quickfix list",
    "",
    "🦀 Rust Commands",
    "  <leader>r     - Run file",
    "  <leader>ra    - Run with arguments",
    "  <leader>cc    - Cargo check",
    "  <leader>ct    - Cargo test",
    "  <leader>cp    - Cargo clippy",
    "  <C-space>     - Hover actions (Rust)",
    "  <leader>a     - Code action group (Rust)",
    "  <leader>rr    - Runnables (Rust)",
    "  <leader>em    - Expand macros (Rust)",
    "  <leader>mj    - Move item down (Rust)",
    "  <leader>mk    - Move item up (Rust)",
    "",
    "🐍 Python Commands",
    "  <leader>r     - Run file",
    "  <leader>ra    - Run with arguments",
    "  <leader>pt    - Run tests",
    "  <leader>pl    - Lint code",
    "  <leader>pf    - Format code",
    "  <leader>pi    - Sort imports",
    "  <leader>doc   - Generate docstring",
    "",
    "🐞 Debugging",
    "  <leader>db    - Toggle breakpoint",
    "  <leader>dc    - Continue debugging",
    "  <leader>do    - Step over",
    "  <leader>di    - Step into",
    "  <leader>dt    - Run test method",
    "",
    "📦 Crates",
    "  <leader>ct    - Toggle crates",
    "  <leader>cr    - Reload crates",
    "  <leader>cv    - Show versions",
    "  <leader>cf    - Show features",
    "",
    "⚙️ Config",
    "  <leader>rc    - Reload configuration",
    "  <leader>cs    - Show this cheat sheet",
    "",
    "Press q or Esc to close this window"  
  }

  local width = 60
  local height = #cheatsheet
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, true, cheatsheet)

  local win_width = vim.api.nvim_get_option("columns")
  local win_height = vim.api.nvim_get_option("lines")
  local row = math.floor((win_height - height) / 2)
  local col = math.floor((win_width - width) / 2)

  local opts = {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
  }

  win_id = vim.api.nvim_open_win(buf, true, opts)
  vim.api.nvim_win_set_option(win_id, "winblend", 10)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
  vim.api.nvim_buf_set_keymap(buf, "n", "q", ":close<CR>", { noremap = true, silent = true })
  vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", ":close<CR>", { noremap = true, silent = true })

  vim.cmd("setlocal filetype=markdown")
end

vim.api.nvim_set_keymap("n", "<leader>cs", ":lua require'keybindings.cheatsheet'.show_cheat_sheet()<CR>", { noremap = true, silent = true })

return M
