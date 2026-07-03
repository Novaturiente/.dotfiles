-- ============================================================================
-- NVIM-TREE: file explorer in a left side panel
-- ============================================================================
return {
	"nvim-tree/nvim-tree.lua",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	cmd = { "NvimTreeToggle", "NvimTreeFocus", "NvimTreeFindFile", "NvimTreeFindFileToggle" },
	keys = {
		{ "<leader>e", "<cmd>NvimTreeFindFileToggle<cr>", desc = "File explorer (reveal current file)" },
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
