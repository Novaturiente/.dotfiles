-- ============================================================================
-- NEOCODE LAYOUT COMMAND
-- ============================================================================
-- Opens NvimTree (left) + editor (center) + Claude Code (right)
-- Triggered by: nvim --cmd "let g:neocode=1" or :NeoCode
vim.api.nvim_create_user_command("NeoCode", function()
	vim.g.neocode_active = true

	-- Open NvimTree (sidebar left)
	vim.cmd("NvimTreeOpen")
	-- Move to the right (editor area)
	vim.cmd("wincmd l")
	-- If we landed on an unmodifiable buffer, create a new one
	if not vim.bo.modifiable then
		vim.cmd("enew")
	end
	-- Remember the editor window
	vim.g.neocode_editor_win = vim.api.nvim_get_current_win()
	-- Show Alpha dashboard in the editor pane
	pcall(vim.cmd, "Alpha")
	-- Open Claude Code (focus goes to terminal)
	vim.cmd("ClaudeCode")
	-- Enable tabline for buffer tabs
	vim.o.showtabline = 2
	require("mini.tabline").setup()
end, { desc = "Open NeoCode layout: NvimTree + Editor + Claude Code" })

-- Auto-launch NeoCode layout when g:neocode is set
vim.api.nvim_create_autocmd("VimEnter", {
	group = vim.api.nvim_create_augroup("neocode-layout", { clear = true }),
	callback = function()
		if vim.g.neocode == 1 then
			-- Defer to ensure all plugins are loaded
			vim.defer_fn(function()
				vim.cmd("NeoCode")
			end, 100)
		end
	end,
	desc = "Auto-open NeoCode layout on startup",
})

-- ============================================================================
-- NEOCODE: Alt+q closes buffer, not window; show Alpha when empty
-- ============================================================================
vim.keymap.set("n", "<A-q>", function()
	if not vim.g.neocode_active then
		-- Default behavior outside neocode
		vim.cmd("bdelete!")
		return
	end
	-- In neocode mode: close buffer, keep the window
	local editor_win = vim.g.neocode_editor_win
	local cur_win = vim.api.nvim_get_current_win()
	-- Only act on the editor pane (not NvimTree or Claude terminal)
	if editor_win and cur_win == editor_win then
		vim.cmd("bdelete!")
		-- Check if any file buffers remain
		vim.schedule(function()
			local bufs = vim.tbl_filter(function(b)
				local bt = vim.bo[b].buftype
				return vim.api.nvim_buf_is_valid(b)
					and vim.api.nvim_buf_is_loaded(b)
					and vim.api.nvim_buf_get_name(b) ~= ""
					and bt ~= "nofile"
					and bt ~= "terminal"
					and bt ~= "prompt"
			end, vim.api.nvim_list_bufs())
			if #bufs == 0 and vim.api.nvim_win_is_valid(editor_win) then
				vim.api.nvim_set_current_win(editor_win)
				pcall(vim.cmd, "Alpha")
			end
		end)
	else
		-- On other panes, just ignore or do nothing
	end
end, { noremap = true, silent = true, desc = "Close buffer (neocode-aware)" })

-- ============================================================================
-- NEOCODE: Open edited files in the editor pane after diff cleanup
-- ============================================================================
vim.api.nvim_create_autocmd("BufRead", {
	group = vim.api.nvim_create_augroup("neocode-file-to-editor", { clear = true }),
	callback = function()
		if not vim.g.neocode_active then
			return
		end
		local editor_win = vim.g.neocode_editor_win
		if not editor_win or not vim.api.nvim_win_is_valid(editor_win) then
			return
		end
		local cur_buf = vim.api.nvim_get_current_buf()
		local bt = vim.bo[cur_buf].buftype
		-- Only move real files to the editor pane
		if bt == "" and vim.api.nvim_buf_get_name(cur_buf) ~= "" then
			vim.api.nvim_win_set_buf(editor_win, cur_buf)
		end
	end,
	desc = "Route opened files to the editor pane in neocode mode",
})

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

vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter" }, { command = "checktime" })
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
-- SHOW ALPHA DASHBOARD WHEN LAST BUFFER IS CLOSED
-- ============================================================================
vim.api.nvim_create_autocmd("BufDelete", {
	group = vim.api.nvim_create_augroup("alpha-on-empty", { clear = true }),
	callback = function()
		vim.schedule(function()
			local bufs = vim.tbl_filter(function(b)
				local bt = vim.bo[b].buftype
				return vim.api.nvim_buf_is_valid(b)
					and vim.api.nvim_buf_is_loaded(b)
					and vim.api.nvim_buf_get_name(b) ~= ""
					and bt ~= "nofile"
					and bt ~= "terminal"
					and bt ~= "prompt"
			end, vim.api.nvim_list_bufs())
			if #bufs == 0 then
				pcall(vim.cmd, "Alpha")
			end
		end)
	end,
	desc = "Show Alpha dashboard when all file buffers are closed",
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
