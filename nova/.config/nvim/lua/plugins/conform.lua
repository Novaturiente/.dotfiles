-- ============================================================================
-- CONFORM: formatting (format on save + manual)
-- ============================================================================
return {
	"stevearc/conform.nvim",
	event = "BufWritePre",
	cmd = "ConformInfo",
	keys = {
		{
			"<leader>cf",
			function()
				require("conform").format({ async = true, lsp_format = "fallback" })
			end,
			desc = "Format buffer",
		},
	},
	opts = {
		formatters_by_ft = {
			lua = { "stylua" },
			python = { "ruff_format" },
			rust = { "rustfmt" },
			go = { "gofmt" },
			sh = { "shfmt" },
			bash = { "shfmt" },
			json = { "jq" },
			yaml = { "prettier" },
		},
		format_on_save = {
			timeout_ms = 1000,
			lsp_format = "fallback",
		},
	},
}
