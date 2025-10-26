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

vim.api.nvim_create_autocmd("LspAttach", {
	callback = function(args)
		vim.defer_fn(function()
			vim.diagnostic.enable(true, { bufnr = args.buf })
		end, 3000) -- Enable after 1 second
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

-- ============================================================================
-- AUTO ENABLE CODE MAP
-- ============================================================================
-- Auto open/close Outline.nvim depending on window width
local function toggle_outline_by_width()
	local width = vim.o.columns

	if width >= 170 then
		-- open outline if not already visible
		if not require("outline").is_open() then
			require("outline").open()
		end
	else
		-- close outline if open
		if require("outline").is_open() then
			require("outline").close()
		end
	end
end

-- Run this whenever the window is resized
vim.api.nvim_create_autocmd("VimResized", {
	callback = toggle_outline_by_width,
})

-- Optional: also run it once when starting Neovim
vim.api.nvim_create_autocmd("VimEnter", {
	callback = toggle_outline_by_width,
})
