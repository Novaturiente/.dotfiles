-- ============================================================================
-- NEOVIM SETTINGS
-- ============================================================================
vim = vim
vim.loader.enable()
vim.o.guifont = "JetBrainsMonoNL Nerd Font Mono:h13"
-- Set <space> as the leader key
vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.g.have_nerd_font = true

-- Disable netrw (nvim-tree replaces it)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Make line numbers default
vim.o.number = true
vim.o.relativenumber = true
-- Enable mouse mode, can be useful for resizing splits for example!
vim.o.mouse = "nvc"
-- Sync clipboard between OS and Neovim.
vim.schedule(function()
	vim.o.clipboard = "unnamedplus"
end)

-- Enable break indent
vim.o.breakindent = true
vim.opt.smartindent = false

-- Save undo history
vim.o.undofile = true

-- Case-insensitive
vim.o.ignorecase = true
vim.o.smartcase = true

-- Keep signcolumn on by default
vim.o.signcolumn = "yes"

-- Decrease update time
vim.o.updatetime = 250
-- Decrease mapped sequence wait time
vim.o.timeoutlen = 300
-- Configure how new splits should be opened
vim.o.splitright = true
vim.o.splitbelow = true

-- Sets how neovim will display certain whitespace characters in the editor.
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4
vim.o.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

-- Preview substitutions live, as you type!
vim.o.inccommand = "split"

-- Command-line completion (native wildmenu, popup style)
vim.o.wildmenu = true
vim.o.wildmode = "longest:full,full"
vim.opt.wildoptions = "pum"

-- Show which line your cursor is on
vim.o.cursorline = true

-- Minimal number of screen lines to keep above and below the cursor.
vim.o.scrolloff = 10

-- Confirm before exit,
vim.o.confirm = true

-- Fold configuration
vim.o.foldcolumn = "1"
vim.o.foldlevel = 99
vim.o.foldlevelstart = 99
vim.o.foldenable = true

-- ============================================================================
-- LAZY.NVIM SETUP
-- ============================================================================
-- Automatically install lazy.nvim if not present
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
	if vim.v.shell_error ~= 0 then
		error("Error cloning lazy.nvim:\n" .. out)
	end
end

vim.env.PATH = "/home/nova/.local/bin:" .. vim.env.PATH

vim.opt.rtp:prepend(lazypath)

-- Non-plugin keymaps
require("config.keymaps")

-- Plugins: auto-import every spec under lua/plugins/
require("lazy").setup({ import = "plugins" })
