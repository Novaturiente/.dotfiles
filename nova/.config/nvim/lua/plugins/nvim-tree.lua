-- ============================================================================
-- NVIM-TREE: file explorer in a left side panel
-- ============================================================================
return {
	"nvim-tree/nvim-tree.lua",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	cmd = { "NvimTreeToggle", "NvimTreeFocus", "NvimTreeFindFile" },
	keys = {
		{ "<leader>e", "<cmd>NvimTreeToggle<cr>", desc = "File explorer" },
		{ "<leader>fe", "<cmd>NvimTreeFindFile<cr>", desc = "Reveal file in tree" },
	},
	opts = {
		view = {
			width = 30,
			side = "left",
		},
		renderer = {
			group_empty = true,
			indent_markers = { enable = true },
		},
		filters = {
			dotfiles = false, -- show hidden files
		},
		git = { enable = true },
		actions = {
			open_file = { quit_on_open = false },
		},
	},
}
