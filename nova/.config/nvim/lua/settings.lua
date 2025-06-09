-- ========================================================
-- ✨ GENERAL SETTINGS
-- ========================================================

local vim = vim
-- Enable line numbers
vim.wo.number = true
-- Set leader key to space
vim.g.mapleader = ' '
-- Use system clipboard
vim.opt.clipboard = 'unnamedplus'
-- Enable mouse support
vim.o.mouse = 'a'
-- Manual folding
vim.o.foldmethod = "manual"
-- Enable folding
vim.o.foldenable = true
-- Set tab to 4 spaces
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true

-- Autocommands to save and load view (including folds)
local remember_folds_group = vim.api.nvim_create_augroup("remember_folds", { clear = true })

vim.api.nvim_create_autocmd({"BufWinLeave"}, {
  pattern = "*",
  callback = function()
    if vim.fn.expand("%:p") ~= "" and vim.fn.buflisted(vim.api.nvim_get_current_buf()) == 1 then
      vim.cmd("mkview")
    end
  end,
  group = remember_folds_group,
})

vim.api.nvim_create_autocmd({"BufWinEnter"}, {
  pattern = "*",
  command = "silent! loadview",
  group = remember_folds_group,
})

vim.opt.sessionoptions:append("folds")

-- LSP specific settings
vim.opt.completeopt = {'menuone', 'noselect', 'noinsert'}
vim.opt.shortmess = vim.opt.shortmess + { c = true}
vim.api.nvim_set_option('updatetime', 300)

vim.cmd([[
set signcolumn=yes
autocmd CursorHold * lua vim.diagnostic.open_float(nil, { focusable = false })
]])

-- Additional diagnostic configuration
vim.diagnostic.config({
  virtual_text = {
    prefix = '●',
    source = "always",
  },
  signs = true,
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
