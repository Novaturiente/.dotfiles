-- ============================================================================
-- NEOVIM KEYBINDINGS CONFIGURATION
-- ============================================================================
local vim = vim
-- ============================================================================
-- BASIC KEYMAPS
-- ============================================================================
-- Use the black hole register for deletions and changes
vim.keymap.set({ "n", "v" }, "c", '"_c')
vim.keymap.set({ "n", "v" }, "C", '"_C')
vim.keymap.set({ "n", "v" }, "x", '"_x')
vim.keymap.set({ "n", "v" }, "X", '"_X')
vim.keymap.set("i", "jk", "<ESC>", { noremap = true })
-- Clear highlights on search when pressing <Esc> in normal mode
vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<CR>", { noremap = true, silent = true, desc = "Clear search highlights" })

-- Normal mode: move single line with K/J
vim.keymap.set("n", "KK", ":m .-2<CR>==", { noremap = true, silent = true, desc = "Move line up" })
vim.keymap.set("n", "JJ", ":m .+1<CR>==", { noremap = true, silent = true, desc = "Move line down" })
-- Visual mode: move multiple selected lines with K/J
vim.keymap.set("v", "KK", ":m '<-2<CR>gv=gv", { noremap = true, silent = true, desc = "Move selection up" })
vim.keymap.set("v", "JJ", ":m '>+1<CR>gv=gv", { noremap = true, silent = true, desc = "Move selection down" })

-- ============================================================================
-- INSERT MODE NAVIGATION
-- ============================================================================
vim.keymap.set("i", "<C-h>", "<C-o>h", { noremap = true, silent = true, desc = "Move left in insert mode" })
vim.keymap.set("i", "<C-j>", "<C-o>j", { noremap = true, silent = true, desc = "Move down in insert mode" })
vim.keymap.set("i", "<C-k><C-k>", "<C-o>k", { noremap = true, silent = true, desc = "Move up in insert mode" })
vim.keymap.set("i", "<C-l>", "<C-o>l", { noremap = true, silent = true, desc = "Move right in insert mode" })
vim.keymap.set("i", "<C-S-h>", "<BS>", { noremap = true, silent = true, desc = "Backspace" })
vim.keymap.set("i", "<C-S-l>", "<Del>", { noremap = true, silent = true, desc = "Delete forward" })
vim.keymap.set("i", "<C-l>", function()
	local c = vim.fn.getline("."):sub(vim.fn.col("."), vim.fn.col("."))
	if c == ")" or c == "]" or c == "}" or c == '"' or c == "'" then
		return "<Right>"
	else
		return "<C-l>"
	end
end, { expr = true, noremap = true, silent = true })
-- ============================================================================
-- WINDOW NAVIGATION
-- ============================================================================
-- Navigate between split windows using Alt + Arrow Keys in normal mode
vim.keymap.set({ "n", "t", "i" }, "<A-Left>", "<C-w>h", { noremap = true, silent = true })
vim.keymap.set({ "n", "t", "i" }, "<A-Down>", "<C-w>j", { noremap = true, silent = true })
vim.keymap.set({ "n", "t", "i" }, "<A-Up>", "<C-w>k", { noremap = true, silent = true })
vim.keymap.set({ "n", "t", "i" }, "<A-Right>", "<C-w>l", { noremap = true, silent = true })
-- Using lkjh
vim.keymap.set({ "n", "t", "i" }, "<A-h>", "<C-w>h", { noremap = true, silent = true })
vim.keymap.set({ "n", "t", "i" }, "<A-j>", "<C-w>j", { noremap = true, silent = true })
vim.keymap.set({ "n", "t", "i" }, "<A-k>", "<C-w>k", { noremap = true, silent = true })
vim.keymap.set({ "n", "t", "i" }, "<A-l>", "<C-w>l", { noremap = true, silent = true })

-- ============================================================================
-- BUFFER NAVIGATION
-- ============================================================================
-- Navigate between buffers using Ctrl + Alt + Arrow Keys
vim.keymap.set("n", "<C-A-Left>", ":bprevious<CR>", { noremap = true, silent = true, desc = "Previous buffer" })
vim.keymap.set("n", "<C-A-h>", ":bprevious<CR>", { noremap = true, silent = true, desc = "Previous buffer" })
vim.keymap.set("n", "<C-A-Right>", ":bnext<CR>", { noremap = true, silent = true, desc = "Next buffer" })
vim.keymap.set("n", "<C-A-l>", ":bnext<CR>", { noremap = true, silent = true, desc = "Next buffer" })

-- ============================================================================
-- BUFFER MANAGEMENT
-- ============================================================================
-- Alt+d forcefully closes the buffer even if there are unsaved changes
vim.keymap.set("n", "<A-q>", ":bdelete!<CR>", { noremap = true, silent = true, desc = "Force Delete current buffer" })
vim.keymap.set(
	"n",
	"<leader>qq",
	":bprevious |:bdelete<CR>",
	{ noremap = true, silent = true, desc = "Close current buffer" }
)
vim.keymap.set("n", "<leader>qw", ":q<CR>", { noremap = true, silent = true, desc = "Exit Neovim" })
vim.keymap.set("n", "<leader>ww", ":w<CR>", { noremap = true, silent = true, desc = "Save file" })

-- ============================================================================
-- WINDOW REPOSITIONING
-- ============================================================================
-- Move current window to another pane using Alt + Shift + Arrow Keys
vim.keymap.set("n", "<A-S-Left>", "<C-w>H", { noremap = true, silent = true, desc = "Move window to far left" })
vim.keymap.set("n", "<A-S-Down>", "<C-w>J", { noremap = true, silent = true, desc = "Move window to far bottom" })
vim.keymap.set("n", "<A-S-Up>", "<C-w>K", { noremap = true, silent = true, desc = "Move window to far top" })
vim.keymap.set("n", "<A-S-Right>", "<C-w>L", { noremap = true, silent = true, desc = "Move window to far right" })
-- Move current window to another pane using Alt + Shift + hjkl
vim.keymap.set("n", "<A-S-h>", "<C-w>H", { noremap = true, silent = true, desc = "Move window to far left" })
vim.keymap.set("n", "<A-S-j>", "<C-w>J", { noremap = true, silent = true, desc = "Move window to far bottom" })
vim.keymap.set("n", "<A-S-k>", "<C-w>K", { noremap = true, silent = true, desc = "Move window to far top" })
vim.keymap.set("n", "<A-S-l>", "<C-w>L", { noremap = true, silent = true, desc = "Move window to far right" })

-- ============================================================================
-- TERMINAL KEYBINDINGS
-- ============================================================================
-- Open terminal in vertical split (in current buffer's directory)
vim.keymap.set("n", "<leader>tt", function()
	local dir = vim.fn.expand("%:p:h")
	vim.cmd("vsplit")
	vim.cmd("lcd " .. dir)
	vim.cmd("terminal")
end, { noremap = true, silent = true, desc = "Open vertical terminal" })
-- Open terminal in horizontal split (in current buffer's directory)
vim.keymap.set("n", "<leader>th", function()
	local dir = vim.fn.expand("%:p:h")
	vim.cmd("split")
	vim.cmd("lcd " .. dir)
	vim.cmd("terminal")
end, { noremap = true, silent = true, desc = "Open horizontal terminal" })
-- Exit terminal mode in the builtin terminal with a shortcut that is a bit easier
vim.keymap.set("t", "jk", "<C-\\><C-n>", { noremap = true, silent = true, desc = "Exit terminal mode" })

-- ============================================================================
-- FILE EXPLORER (OIL.NVIM) - TOGGLE LEFT SIDEBAR
-- ============================================================================
vim.keymap.set("n", "<leader>e", function()
	if vim.bo.filetype == "oil" then
		require("oil.actions").close.callback()
	else
		vim.cmd("Oil --float")
	end
end, { desc = "Toggle Oil" })

-- ============================================================================
-- TELESCOPE FUZZY FINDER
-- ============================================================================
-- text, help docs, and more. All bindings use <leader>s prefix for search.
local builtin = require("telescope.builtin")
-- Search Commands
vim.keymap.set("n", "<leader>fh", builtin.help_tags, { desc = "[S]earch [H]elp" })
vim.keymap.set("n", "<leader>fk", builtin.keymaps, { desc = "[S]earch [K]eymaps" })
vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "[S]earch [F]iles" })
vim.keymap.set("n", "<leader>fs", builtin.builtin, { desc = "[S]earch [S]elect Telescope" })
vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "[S]earch by [G]rep" })
vim.keymap.set("n", "<leader>fd", builtin.diagnostics, { desc = "[D]iagnostics" })
vim.keymap.set("n", "<leader>fr", builtin.oldfiles, { desc = 'Recent Files ("." for repeat)' })
vim.keymap.set("n", "<leader><leader>", builtin.buffers, { desc = "Find existing buffers" })
-- Advanced Telescope Commands
-- Fuzzy search in current buffer with custom theme
vim.keymap.set("n", "<leader>/", function()
	builtin.current_buffer_fuzzy_find(require("telescope.themes").get_dropdown({
		winblend = 10,
		previewer = false,
	}))
end, { desc = "Search in current buffer" })
-- Search Neovim configuration files
vim.keymap.set("n", "<leader>fn", function()
	builtin.find_files({ cwd = vim.fn.stdpath("config") })
end, { desc = "[S]earch [N]eovim files" })

-- ============================================================================
-- LSP (LANGUAGE SERVER PROTOCOL) KEYBINDINGS
-- ============================================================================
vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("lsp-keybindings", { clear = true }),
	callback = function(event)
		-- Automatically sets the buffer and adds "LSP: " prefix to descriptions
		local map = function(keys, func, desc, mode)
			mode = mode or "n"
			vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
		end
		-- Code Navigation
		map("grd", require("telescope.builtin").lsp_definitions, "[G]oto [D]efinition")
		map("grD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")
		map("gri", require("telescope.builtin").lsp_implementations, "[G]oto [I]mplementation")
		map("grt", require("telescope.builtin").lsp_type_definitions, "[G]oto [T]ype Definition")
		map("grr", require("telescope.builtin").lsp_references, "[G]oto [R]eferences")
		-- Symbol Navigation
		map("grO", require("telescope.builtin").lsp_document_symbols, "Open Document Symbols")
		map("grW", require("telescope.builtin").lsp_dynamic_workspace_symbols, "Open Workspace Symbols")
		-- Code Actions
		map("grn", vim.lsp.buf.rename, "[R]e[n]ame")
		map("gra", vim.lsp.buf.code_action, "[C]ode [A]ction", { "n", "x" })
		-- Helper function to check LSP method support across Neovim versions
		local function client_supports_method(client, method, bufnr)
			if vim.fn.has("nvim-0.11") == 1 then
				return client:supports_method(method, bufnr)
			else
				return client.supports_method(method, { bufnr = bufnr })
			end
		end
		-- ====================================================================
		-- DOCUMENT HIGHLIGHT SETUP
		-- ====================================================================
		-- Automatically highlight references to the symbol under cursor
		local client = vim.lsp.get_client_by_id(event.data.client_id)
		if
			client
			and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_documentHighlight, event.buf)
		then
			local highlight_augroup = vim.api.nvim_create_augroup("lsp-highlight", { clear = false })
			-- Highlight references when cursor stops moving
			vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
				buffer = event.buf,
				group = highlight_augroup,
				callback = vim.lsp.buf.document_highlight,
			})
			-- Clear highlights when cursor moves
			vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
				buffer = event.buf,
				group = highlight_augroup,
				callback = vim.lsp.buf.clear_references,
			})
			-- Clean up when LSP detaches
			vim.api.nvim_create_autocmd("LspDetach", {
				group = vim.api.nvim_create_augroup("lsp-detach", { clear = true }),
				callback = function(event2)
					vim.lsp.buf.clear_references()
					vim.api.nvim_clear_autocmds({ group = "lsp-highlight", buffer = event2.buf })
				end,
			})
		end
		-- ====================================================================
		-- INLAY HINTS TOGGLE
		-- ====================================================================
		-- Inlay hints show additional type information and parameter names
		if client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf) then
			map("<leader>gh", function()
				vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = event.buf }))
			end, "[T]oggle Inlay [H]ints")
		end
	end,
})

-- ============================================================================
-- CODE FORMATTING
-- ============================================================================
-- Format the current buffer using conform.nvim
vim.keymap.set("n", "<leader>=", function()
	require("conform").format({ async = true, lsp_format = "fallback" })
end, { desc = "Format buffer" })

-- ============================================================================
-- NEOGIT
-- ============================================================================
local neogit = require("neogit")
-- Helper to get project root of the current buffer
local function get_project_root()
	local cwd
	-- Check if current buffer is an oil.nvim buffer
	local bufname = vim.api.nvim_buf_get_name(0)
	if bufname:match("^oil://") then
		-- Get directory from oil.nvim
		local ok, oil = pcall(require, "oil")
		if ok then
			cwd = oil.get_current_dir()
		else
			vim.notify("Oil.nvim not available", vim.log.levels.ERROR)
			return nil
		end
	else
		-- Regular file buffer - get directory of current file
		cwd = vim.fn.expand("%:p:h")
	end
	-- Find git root from the current directory
	local root = vim.fn.systemlist("git -C " .. vim.fn.shellescape(cwd) .. " rev-parse --show-toplevel")[1]
	if vim.v.shell_error ~= 0 then
		vim.notify("Not a git repository", vim.log.levels.ERROR)
		return nil
	end
	return root
end
vim.keymap.set("n", "<leader>gg", function()
	local root = get_project_root()
	if root then
		vim.cmd("lcd " .. root) -- change local working directory
		neogit.open({ cwd = root }) -- open Neogit in that directory
	end
end, { desc = "Open Neogit in current project's git root" })

-- ============================================================================
-- MESSAGE MANAGEMENT KEYMAPS
-- ============================================================================
-- Show messages in a new buffer (native method)
vim.keymap.set("n", "<leader>ms", function()
	vim.cmd("messages")
end, { noremap = true, silent = true, desc = "Show messages" })

-- ============================================================================
-- TROUBLE KEYBINDINGS
-- ============================================================================
-- Toggle diagnostics for all buffers
vim.keymap.set("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", {
	noremap = true,
	silent = true,
	desc = "Toggle Trouble diagnostics",
})
-- Toggle diagnostics for current buffer only
vim.keymap.set("n", "<leader>xX", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", {
	noremap = true,
	silent = true,
	desc = "Toggle buffer diagnostics",
})
-- Toggle document symbols
vim.keymap.set("n", "<leader>cs", "<cmd>Trouble symbols toggle focus=false<cr>", {
	noremap = true,
	silent = true,
	desc = "Toggle symbols (Trouble)",
})
-- Toggle LSP definitions/references
vim.keymap.set("n", "<leader>cl", "<cmd>Trouble lsp toggle focus=false win.position=right<cr>", {
	noremap = true,
	silent = true,
	desc = "Toggle LSP definitions/references",
})
-- Toggle location list
vim.keymap.set("n", "<leader>xL", "<cmd>Trouble loclist toggle<cr>", {
	noremap = true,
	silent = true,
	desc = "Toggle location list",
})
-- Toggle quickfix list
vim.keymap.set("n", "<leader>xQ", "<cmd>Trouble qflist toggle<cr>", {
	noremap = true,
	silent = true,
	desc = "Toggle quickfix list",
})

-- ============================================================================
-- COMMAND LINE MODE KEYBINDINGS
-- ============================================================================
-- Paste from system clipboard
vim.keymap.set("c", "<C-a>", "<Home>", { noremap = true, desc = "Move to start of line" })
-- Move to end of line
vim.keymap.set("c", "<C-e>", "<End>", { noremap = true, desc = "Move to end of line" })
-- Delete word backward
vim.keymap.set("c", "<C-BS>", "<C-w>", { noremap = true, desc = "Delete word backward" })

-- ============================================================================
-- COLORSCHEME SWITCHING
-- ============================================================================
-- Define available colorschemes
local colorschemes = {
	"rose-pine-moon",
	"yorumi",
	"tokyonight-night",
	"vague",
}
local current_scheme_index = 1
vim.cmd.colorscheme(colorschemes[current_scheme_index])
-- Function to cycle through colorschemes
local function select_colorscheme()
	vim.ui.select(colorschemes, {
		prompt = "Select Colorscheme:",
		format_item = function(item)
			return item
		end,
	}, function(choice)
		if choice then
			vim.cmd.colorscheme(choice)
			print("Colorscheme: " .. choice)
		end
	end)
end
-- Keybinding to cycle colorschemes using Ctrl + Alt + C
vim.keymap.set("n", "<C-A-c>", select_colorscheme, {
	noremap = true,
	silent = true,
	desc = "Cycle through colorschemes",
})

-- ============================================================================
-- CUSTOM COMMAND LINE MODE WITH SPECIFIC KEYBINDINGS
-- ============================================================================
local in_custom_cmdline = false
-- Function to open command line with ":e " pre-filled and custom keybindings
local function open_file_browser()
	in_custom_cmdline = true
	-- Custom backspace behavior
	vim.keymap.set("c", "<BS>", function()
		local cmdline = vim.fn.getcmdline()
		local pos = vim.fn.getcmdpos() - 1
		local last_char = cmdline:sub(pos, pos)
		if last_char == "/" then
			return "<C-w><C-w>"
		else
			return "<BS>"
		end
	end, { expr = true, noremap = true })
	-- Paste from system clipboard
	vim.keymap.set("c", "<C-v>", "<C-r>+", { noremap = true })
	-- Get current buffer's directory path
	local home = vim.fn.expand("~")
	local current_dir = vim.fn.expand("%:p:h")
	if current_dir == "" or current_dir == "." then
		current_dir = home
	end
	if current_dir:sub(1, #home) == home then
		current_dir = "~" .. current_dir:sub(#home + 1)
	end
	local cmd = ":e " .. current_dir .. "/"
	local keys = vim.api.nvim_replace_termcodes(cmd .. "<C-d>", true, false, true)
	vim.fn.feedkeys(keys, "n")
end
-- Autocmd to clean up keybindings when leaving command line
vim.api.nvim_create_autocmd("CmdlineLeave", {
	group = vim.api.nvim_create_augroup("CustomCmdlineCleanup", { clear = true }),
	callback = function()
		if in_custom_cmdline then
			-- Remove custom keybindings
			pcall(vim.keymap.del, "c", "<BS>")
			pcall(vim.keymap.del, "c", "<C-v>")
			in_custom_cmdline = false
		end
	end,
})
-- Keybinding to trigger the custom command line
vim.keymap.set("n", "<leader>.", open_file_browser, {
	noremap = true,
	silent = true,
	desc = "Open file",
})
