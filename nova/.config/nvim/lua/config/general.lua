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
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.loader.enable()
vim.opt.updatetime = 300

-- Enable persistent undo
vim.o.undofile = true
-- Set undo directory
vim.o.undodir = vim.fn.stdpath("data") .. "/undo"

vim.opt.conceallevel = 1

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

-- Prevent errors when plugins are not yet installed
local function safe_require(module)
  local success, result = pcall(require, module)
  if not success then
    vim.notify("Module " .. module .. " not found. Run :Lazy sync to install missing plugins.", vim.log.levels.WARN)
    return nil
  end
  return result
end

vim.lsp.set_log_level("error")
vim.opt.fsync = false

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
