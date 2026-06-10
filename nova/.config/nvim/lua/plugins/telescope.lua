-- ============================================================================
-- TELESCOPE: fuzzy finder (files, grep, symbols)
-- ============================================================================
return {
	"nvim-telescope/telescope.nvim",
	cmd = "Telescope",
	dependencies = {
		"nvim-lua/plenary.nvim",
		{
			"nvim-telescope/telescope-fzf-native.nvim",
			build = "make",
			cond = function()
				return vim.fn.executable("make") == 1
			end,
		},
	},
	keys = {
		{ "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find files" },
		{ "<leader>fg", "<cmd>Telescope live_grep<cr>", desc = "Live grep" },
		{ "<leader>fb", "<cmd>Telescope buffers<cr>", desc = "Buffers" },
		{ "<leader>fr", "<cmd>Telescope oldfiles<cr>", desc = "Recent files" },
		{ "<leader>fh", "<cmd>Telescope help_tags<cr>", desc = "Help tags" },
		{ "<leader>fd", "<cmd>Telescope diagnostics<cr>", desc = "Diagnostics" },
		{ "<leader>fk", "<cmd>Telescope keymaps<cr>", desc = "Keymaps" },
		{ "<leader>/", "<cmd>Telescope current_buffer_fuzzy_find<cr>", desc = "Search buffer" },
	},
	opts = {
		pickers = {
			find_files = { hidden = true, file_ignore_patterns = { "%.git/" } },
		},
	},
	config = function(_, opts)
		require("telescope").setup(opts)
		pcall(require("telescope").load_extension, "fzf")
	end,
}
