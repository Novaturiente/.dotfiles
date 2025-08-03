local vim = vim

-- =============================
-- Line Numbers
-- =============================
-- Enable line numbers
vim.wo.number = true
vim.opt.relativenumber = true

-- Auto switch line numbers on mode change
vim.api.nvim_create_autocmd({ "InsertEnter" }, {
  pattern = "*",
  callback = function()
    vim.opt.relativenumber = false
  end,
})

vim.api.nvim_create_autocmd({ "InsertLeave" }, {
  pattern = "*",
  callback = function()
    vim.opt.relativenumber = true
  end,
})

-- =============================
-- General Settings
-- =============================
-- Set leader key to space
vim.g.mapleader = ' '

-- Use system clipboard
vim.opt.clipboard = 'unnamedplus'

-- Enable mouse support
vim.o.mouse = 'a'

-- Manual folding
vim.o.foldmethod = "manual"
vim.o.foldenable = true

-- Set tab to 2 spaces
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true

-- Faster update time
vim.opt.updatetime = 300

-- Enable persistent undo
vim.o.undofile = true
vim.o.undodir = vim.fn.stdpath("data") .. "/undo"

-- Conceal level (used in markdown and other filetypes)
vim.opt.conceallevel = 1

-- Enable faster startup (requires Neovim 0.9+)
vim.loader.enable()

-- Set LSP log level
vim.lsp.set_log_level("error")

-- Disable fsync on write
vim.opt.fsync = false

-- Disable copy while pasting
vim.keymap.set("x", "p", [["_dP]], { noremap = true, silent = true })

-- =============================
-- Remember Fold Views
-- =============================
local remember_folds_group = vim.api.nvim_create_augroup("remember_folds", { clear = true })

vim.api.nvim_create_autocmd({ "BufWinLeave" }, {
  pattern = "*",
  callback = function()
    if vim.fn.expand("%:p") ~= "" and vim.fn.buflisted(vim.api.nvim_get_current_buf()) == 1 then
      vim.cmd("mkview")
    end
  end,
  group = remember_folds_group,
})

vim.api.nvim_create_autocmd({ "BufWinEnter" }, {
  pattern = "*",
  command = "silent! loadview",
  group = remember_folds_group,
})

-- Include folds in session options
vim.opt.sessionoptions:append("folds")

-- =============================
-- Treesitter Highlighting Fallback
-- =============================
vim.api.nvim_create_autocmd("FileType", {
  pattern = "*",
  callback = function()
    pcall(function() vim.cmd("TSEnable highlight") end)
  end,
})

-- =============================
-- Lazy.nvim Bootstrap
-- =============================
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    'git', 'clone', '--filter=blob:none', 'https://github.com/folke/lazy.nvim.git',
    '--branch=stable', lazypath,
  })
end
vim.opt.runtimepath:prepend(lazypath)
