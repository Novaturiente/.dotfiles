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

-- ============================================================================
-- AUTO-CREATE DIRECTORIES GLOBALLY
-- ============================================================================

-- Method 1: Autocmd (recommended - works everywhere)
vim.api.nvim_create_autocmd({ "BufWritePre", "FileWritePre" }, {
	group = vim.api.nvim_create_augroup("auto_create_dir", { clear = true }),
	callback = function(event)
		local file = vim.fn.expand("<afile>")

		-- Skip special buffers and URLs (oil://, ftp://, etc.)
		if vim.bo[event.buf].buftype ~= "" or file:match("^%w+://") then
			return
		end

		local dir = vim.fn.fnamemodify(file, ":p:h")

		-- Create directory if it doesn't exist (with all parents)
		if vim.fn.isdirectory(dir) == 0 then
			vim.fn.mkdir(dir, "p")
		end
	end,
	desc = "Auto-create parent directories when saving",
})
