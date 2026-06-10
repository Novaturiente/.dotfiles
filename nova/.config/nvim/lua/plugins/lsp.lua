-- ============================================================================
-- LSP: nvim-lspconfig + mason (native vim.lsp API, nvim 0.11+)
-- ============================================================================
return {
	"neovim/nvim-lspconfig",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = {
		{ "mason-org/mason.nvim", opts = {} },
		"mason-org/mason-lspconfig.nvim",
		"saghen/blink.cmp",
	},
	config = function()
		-- Per-server settings (keys = lspconfig server names)
		local servers = {
			lua_ls = {
				settings = {
					Lua = {
						completion = { callSnippet = "Replace" },
						diagnostics = { globals = { "vim" } },
					},
				},
			},
			pyright = {},
			rust_analyzer = {},
			gopls = {},
			bashls = {},
		}

		-- Diagnostics display
		vim.diagnostic.config({
			severity_sort = true,
			float = { border = "rounded", source = "if_many" },
			underline = { severity = vim.diagnostic.severity.ERROR },
			virtual_text = { source = "if_many", spacing = 2 },
			signs = vim.g.have_nerd_font and {
				text = {
					[vim.diagnostic.severity.ERROR] = "󰅚 ",
					[vim.diagnostic.severity.WARN] = "󰀪 ",
					[vim.diagnostic.severity.INFO] = "󰋽 ",
					[vim.diagnostic.severity.HINT] = "󰌶 ",
				},
			} or {},
		})

		-- Completion capabilities (blink) applied to every server
		vim.lsp.config("*", {
			capabilities = require("blink.cmp").get_lsp_capabilities(),
		})
		for name, cfg in pairs(servers) do
			vim.lsp.config(name, cfg)
		end

		require("mason-lspconfig").setup({
			ensure_installed = vim.tbl_keys(servers),
			automatic_enable = true, -- vim.lsp.enable installed servers
		})

		-- Buffer-local keymaps on attach
		vim.api.nvim_create_autocmd("LspAttach", {
			group = vim.api.nvim_create_augroup("lsp-attach", { clear = true }),
			callback = function(event)
				local map = function(keys, fn, desc, mode)
					vim.keymap.set(mode or "n", keys, fn, { buffer = event.buf, desc = "LSP: " .. desc })
				end
				local tb = require("telescope.builtin")
				map("gd", tb.lsp_definitions, "Goto Definition")
				map("gr", tb.lsp_references, "Goto References")
				map("gi", tb.lsp_implementations, "Goto Implementation")
				map("gD", vim.lsp.buf.declaration, "Goto Declaration")
				map("K", vim.lsp.buf.hover, "Hover")
				map("<leader>lr", vim.lsp.buf.rename, "Rename")
				map("<leader>la", vim.lsp.buf.code_action, "Code Action", { "n", "x" })
				map("<leader>ld", vim.diagnostic.open_float, "Line Diagnostics")
				map("<leader>ls", tb.lsp_document_symbols, "Document Symbols")
				map("[d", function()
					vim.diagnostic.jump({ count = -1 })
				end, "Prev Diagnostic")
				map("]d", function()
					vim.diagnostic.jump({ count = 1 })
				end, "Next Diagnostic")
			end,
		})
	end,
}
