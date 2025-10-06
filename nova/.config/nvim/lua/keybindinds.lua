-- ============================================================================
-- NEOVIM KEYBINDINGS CONFIGURATION
-- ============================================================================
-- This file contains all custom keybindings for Neovim.
-- Organized by functionality for easy navigation and maintenance.
-- ============================================================================

-- ============================================================================
-- WINDOW NAVIGATION
-- ============================================================================
-- Navigate between split windows using Alt + Arrow Keys
-- These keybindings allow quick movement between window splits without
-- using the default Ctrl-w prefix
vim.keymap.set("n", "<A-Left>", "<C-w>h", { noremap = true, silent = true, desc = "Move to left window" })
vim.keymap.set("n", "<A-Down>", "<C-w>j", { noremap = true, silent = true, desc = "Move to window below" })
vim.keymap.set("n", "<A-Up>", "<C-w>k", { noremap = true, silent = true, desc = "Move to window above" })
vim.keymap.set("n", "<A-Right>", "<C-w>l", { noremap = true, silent = true, desc = "Move to right window" })

-- ============================================================================
-- BUFFER NAVIGATION
-- ============================================================================
-- Navigate between buffers using Ctrl + Alt + Arrow Keys
-- Buffers are open files in memory that you can switch between
vim.keymap.set("n", "<C-A-Left>", ":bprevious<CR>", { noremap = true, silent = true, desc = "Previous buffer" })
vim.keymap.set("n", "<C-A-Right>", ":bnext<CR>", { noremap = true, silent = true, desc = "Next buffer" })

-- ============================================================================
-- BUFFER MANAGEMENT
-- ============================================================================
-- Close the current buffer without closing the window
-- Alt+d forcefully closes the buffer even if there are unsaved changes
vim.keymap.set("n", "<A-d>", ":bdelete!<CR>", { noremap = true, silent = true, desc = "Delete current buffer" })

-- ============================================================================
-- TELESCOPE FUZZY FINDER
-- ============================================================================
-- Telescope is a highly extendable fuzzy finder for searching files,
-- text, help docs, and more. All bindings use <leader>s prefix for search.
-- See `:help telescope.builtin` for more information
local builtin = require("telescope.builtin")

-- Search Commands
vim.keymap.set("n", "<leader>sh", builtin.help_tags, { desc = "[S]earch [H]elp" })
vim.keymap.set("n", "<leader>sk", builtin.keymaps, { desc = "[S]earch [K]eymaps" })
vim.keymap.set("n", "<leader>sf", builtin.find_files, { desc = "[S]earch [F]iles" })
vim.keymap.set("n", "<leader>ss", builtin.builtin, { desc = "[S]earch [S]elect Telescope" })
vim.keymap.set("n", "<leader>sw", builtin.grep_string, { desc = "[S]earch current [W]ord" })
vim.keymap.set("n", "<leader>sg", builtin.live_grep, { desc = "[S]earch by [G]rep" })
vim.keymap.set("n", "<leader>sd", builtin.diagnostics, { desc = "[S]earch [D]iagnostics" })
vim.keymap.set("n", "<leader>sr", builtin.resume, { desc = "[S]earch [R]esume" })
vim.keymap.set("n", "<leader>s.", builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
vim.keymap.set("n", "<leader><leader>", builtin.buffers, { desc = "[ ] Find existing buffers" })

-- Advanced Telescope Commands
-- Fuzzy search in current buffer with custom theme
vim.keymap.set("n", "<leader>/", function()
	builtin.current_buffer_fuzzy_find(require("telescope.themes").get_dropdown({
		winblend = 10,
		previewer = false,
	}))
end, { desc = "[/] Fuzzily search in current buffer" })

-- Search Neovim configuration files
vim.keymap.set("n", "<leader>sn", function()
	builtin.find_files({ cwd = vim.fn.stdpath("config") })
end, { desc = "[S]earch [N]eovim files" })

-- Open file browser in current file's directory
vim.keymap.set(
	"n",
	"<leader>.",
	":Telescope file_browser path=%:p:h select_buffer=true hidden=true<CR>",
	{ desc = "Open file browser" }
)

-- ============================================================================
-- LSP (LANGUAGE SERVER PROTOCOL) KEYBINDINGS
-- ============================================================================
-- LSP provides IDE-like features such as go-to-definition, find references,
-- code actions, and more. These keybindings are only active when an LSP
-- server is attached to the current buffer.
-- See `:help lsp` for more information
vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("lsp-keybindings", { clear = true }),
	callback = function(event)
		-- Helper function to create LSP keybindings
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
		-- Handles API differences between Neovim 0.10 and 0.11
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
		-- when the cursor is held still for a moment
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
		-- inline with your code. Toggle with <leader>th if supported.
		if client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf) then
			map("<leader>th", function()
				vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = event.buf }))
			end, "[T]oggle Inlay [H]ints")
		end
	end,
})

-- ============================================================================
-- CODE FORMATTING
-- ============================================================================
-- Format the current buffer using conform.nvim
-- Falls back to LSP formatting if no formatter is configured
-- See `:help conform.nvim` for more information
vim.keymap.set("", "<leader>ff", function()
	require("conform").format({ async = true, lsp_format = "fallback" })
end, { desc = "[F]ormat buffer" })

-- ============================================================================
-- NEOGIT CONFIGURATION
-- ============================================================================
-- Require Neogit
local neogit = require("neogit")

-- Helper to get project root of the current buffer
local function get_project_root()
	-- You can use builtin LSP or 'plenary' or fallback to git root
	local cwd = vim.fn.expand("%:p:h") -- directory of current file
	local root = vim.fn.systemlist("git -C " .. cwd .. " rev-parse --show-toplevel")[1]
	if vim.v.shell_error ~= 0 then
		vim.notify("Not a git repository", vim.log.levels.ERROR)
		return nil
	end
	return root
end

-- Keymap to open Neogit in the current buffer's project
vim.keymap.set("n", "<leader>gg", function()
	local root = get_project_root()
	if root then
		vim.cmd("lcd " .. root) -- change local working directory
		neogit.open({ cwd = root }) -- open Neogit in that directory
	end
end, { desc = "Open Neogit in current project's git root" })
