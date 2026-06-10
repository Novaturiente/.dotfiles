-- ============================================================================
-- LUALINE: statusline
-- ============================================================================
return {
	"nvim-lualine/lualine.nvim",
	event = "VeryLazy",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	opts = {
		options = {
			theme = "catppuccin-mocha",
			globalstatus = true, -- single statusline across splits
			section_separators = "",
			component_separators = "|",
		},
		sections = {
			lualine_c = { { "filename", path = 1 } }, -- relative path
			lualine_x = { "diagnostics", "filetype" },
		},
	},
}
