-- ============================================================================
-- BUFFERLINE: buffers shown as tabs along the top
-- ============================================================================
return {
	"akinsho/bufferline.nvim",
	event = "VeryLazy",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	opts = {
		options = {
			mode = "buffers",
			diagnostics = "nvim_lsp",
			separator_style = "thin",
			show_buffer_close_icons = true,
			show_close_icon = false,
			offsets = {
				{ filetype = "NvimTree", text = "Files", separator = true },
			},
		},
	},
	keys = {
		{ "<leader>bp", "<cmd>BufferLinePick<CR>", desc = "Pick buffer" },
	},
}
