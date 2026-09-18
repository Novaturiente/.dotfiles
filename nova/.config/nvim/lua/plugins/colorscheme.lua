-- ============================================================================
-- COLORSCHEME
-- ============================================================================
-- The palette comes from lua/theme.lua, which scripts/theme.sh regenerates
-- from system/themes/palettes/<name>.env. Catppuccin is used as the rendering
-- engine for every theme: its color_overrides table accepts all 26 palette
-- slots, so a different theme is a different set of hexes rather than a
-- different plugin.
--
-- ponytail: one colorscheme plugin, not one per theme. Add a dedicated plugin
-- only if a theme needs different highlight-group semantics, not just hexes.
local theme = require("theme")

return {
	"catppuccin/nvim",
	name = "catppuccin",
	lazy = false, -- main colorscheme: load at startup
	priority = 1000, -- load before other plugins
	opts = {
		flavour = "mocha",
		transparent_background = false,
		color_overrides = {
			mocha = theme.palette,
		},
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
