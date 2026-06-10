-- ============================================================================
-- COLORSCHEME: Catppuccin
-- ============================================================================
return {
	"catppuccin/nvim",
	name = "catppuccin",
	lazy = false, -- main colorscheme: load at startup
	priority = 1000, -- load before other plugins
	opts = {
		flavour = "mocha", -- latte, frappe, macchiato, mocha
		transparent_background = false,
		integrations = {
			treesitter = true,
			native_lsp = { enabled = true },
			telescope = { enabled = true },
			gitsigns = true,
			which_key = true,
			mason = true,
			cmp = true,
		},
	},
	config = function(_, opts)
		require("catppuccin").setup(opts)
		vim.cmd.colorscheme("catppuccin-mocha")
	end,
}
