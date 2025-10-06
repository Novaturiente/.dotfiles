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
-- Automatically open terminal when starting without file arguments
vim.api.nvim_create_autocmd("VimEnter", {
	pattern = "*",
	callback = function()
		if vim.fn.argc() == 0 then
			vim.cmd("terminal")
			-- Schedule to run after terminal is fully initialized
			vim.schedule(function()
				vim.cmd("startinsert")
				vim.opt_local.number = false
				vim.opt_local.relativenumber = false
			end)
		end
	end,
	desc = "Open terminal when starting Neovim without file arguments",
})

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
