-- ============================================================================
-- AUTOCOMMANDS
-- ============================================================================
-- Highlight when yanking (copying) text
vim.api.nvim_create_autocmd("TextYankPost", {
	group = vim.api.nvim_create_augroup("kickstart-highlight-yank", { clear = true }),
	callback = function()
		vim.hl.on_yank()
	end,
	desc = "Highlight when yanking (copying) text",
})

-- ============================================================================
-- TERMINAL AUTO CONFIGURATION
-- ============================================================================

-- Automatically enter insert mode in terminal buffers (for splits/new terminals)
vim.api.nvim_create_autocmd("TermOpen", {
	pattern = "*",
	callback = function()
		vim.cmd("startinsert")
		vim.opt_local.number = false
		vim.opt_local.relativenumber = false
	end,
	desc = "Auto enter insert mode and configure terminal buffers",
})

-- ============================================================================
-- SUPPRESS INITIAL DIAGNOSTIC FLOOD (UPDATED API)
-- ============================================================================
-- Hide diagnostics on file open and enable after first save
-- Prevents incorrect errors while LSP server indexes the project

vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
	callback = function(args)
		vim.diagnostic.enable(false, { bufnr = args.buf })
	end,
})

vim.api.nvim_create_autocmd("BufWritePost", {
	callback = function(args)
		vim.diagnostic.enable(true, { bufnr = args.buf })
	end,
})
