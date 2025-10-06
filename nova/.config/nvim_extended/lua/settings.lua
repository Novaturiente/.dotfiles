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
-- vim.keymap.set("x", "gp", [["_dP]], { noremap = true, silent = true })
vim.keymap.set("x", "p", function()
  -- Save current unnamed register and its type
  local saved_reg = vim.fn.getreg('"')
  local saved_regtype = vim.fn.getregtype('"')

  -- Delete selection into black hole register (no clipboard overwrite)
  vim.cmd('normal! "_d')

  -- Restore unnamed register contents
  vim.fn.setreg('"', saved_reg, saved_regtype)

  -- Paste after the cursor with 'p'
  vim.cmd('normal! p')
end, { noremap = true, silent = true })

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

-- Function to confirm closing without saving
local function confirm_quit()
  if vim.bo.modified then
    vim.ui.select({ "Yes", "No\n" }, {
      prompt = "Buffer has unsaved changes. Close without saving?",
    }, function(choice)
      if choice == "Yes" or "" then
        vim.cmd("q!")
      end
      -- if No, do nothing
    end)
  else
    vim.cmd("q")
  end
end
vim.api.nvim_create_user_command("Q", confirm_quit, {})
vim.cmd([[
  cabbrev q Q
]])

-- Open Dashboard when last buffer closed
vim.api.nvim_create_autocmd("BufDelete", {
  callback = function()
    -- Small delay to let Neovim finish buffer operations
    vim.defer_fn(function()
      local buffers = vim.fn.getbufinfo({ buflisted = 1 })
      local normal_buffers = 0
      local empty_buffers = 0

      for _, buf in ipairs(buffers) do
        local ft = vim.api.nvim_buf_get_option(buf.bufnr, "filetype")
        local bt = vim.api.nvim_buf_get_option(buf.bufnr, "buftype")
        local name = vim.api.nvim_buf_get_name(buf.bufnr)

        -- Check if buffer is empty (no name, no filetype, no content)
        if name == "" and ft == "" and bt == "" then
          local lines = vim.api.nvim_buf_get_lines(buf.bufnr, 0, -1, false)
          if #lines == 1 and lines[1] == "" then
            empty_buffers = empty_buffers + 1
          end
        elseif ft ~= "" and bt == "" then
          normal_buffers = normal_buffers + 1
        end
      end

      -- If only empty buffers remain, open dashboard
      if normal_buffers == 0 and empty_buffers > 0 then
        vim.cmd("Dashboard")
      end
    end, 10) -- 10ms delay
  end,
})
