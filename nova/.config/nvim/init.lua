-- ========================================================
-- ✨ GENERAL SETTINGS
-- ========================================================
local vim = vim

vim.loader.enable()
vim.opt.updatetime = 300

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

-- Load core settings
require('settings')

-- ========================================================
-- 📦 PLUGIN MANAGEMENT (Lazy.nvim)
-- ========================================================

require('lazy').setup({
  -- == THEME ==
  {
    "folke/tokyonight.nvim",
    name = 'tokyonight',
    lazy = false,
    priority = 1000,
   config = function()
      require('tokyonight').setup({})
      vim.cmd('colorscheme tokyonight-night')
    end,
  },
  -- Load plugins from lua/plugins.lua
  require('plugins'),
})

-- ========================================================
-- 🌳 UI and UX Enhancements (Configuration)
-- ========================================================

require("noice").setup({
  lsp = {
    override = {
      ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
      ["vim.lsp.util.stylize_markdown"] = true,
      ["cmp.entry.get_documentation"] = true,
    },
  },
  presets = {
    bottom_search = true,
    command_palette = true,
    long_message_to_split = true,
    inc_rename = false,
    lsp_doc_border = false,
  },
})

local signs = { Error = " ", Warn = " ", Hint = " ", Info = " " }
for type, icon in pairs(signs) do
  local hl = "DiagnosticSign" .. type
  vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = hl })
end

require("notify").setup({
  timeout = 300,
  top_down = false,
})

-- Initialize which-key
require("which-key").setup({
  plugins = {
    marks = true,
    registers = true,
    spelling = {
      enabled = true,
      suggestions = 20,
    },
    presets = {
      operators = true,
      motions = true,
      text_objects = true,
      windows = true,
      nav = true,
      z = true,
      g = true,
    },
  },
  window = {
    border = "rounded",
    position = "bottom",
    margin = { 1, 0, 1, 0 },
    padding = { 2, 2, 2, 2 },
  },
})

-- ========================================================
-- 🛠️ HELPER FUNCTIONS (LSP & DAP Setup)
-- ========================================================
require('lsp.setup')

-- ========================================================
-- 🗝️ KEYBINDINGS
-- ========================================================
require('keymaps')

-- ========================================================
-- 📂 AUTOCOMMANDS
-- ========================================================
require('autocmds')
