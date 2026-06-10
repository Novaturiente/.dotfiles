-- ============================================================================
-- GITSIGNS: git diff signs in the gutter + hunk actions
-- ============================================================================
return {
	"lewis6991/gitsigns.nvim",
	event = { "BufReadPre", "BufNewFile" },
	opts = {
		signs = {
			add = { text = "+" },
			change = { text = "~" },
			delete = { text = "_" },
			topdelete = { text = "‾" },
			changedelete = { text = "~" },
		},
		on_attach = function(bufnr)
			local gs = require("gitsigns")
			local map = function(keys, fn, desc)
				vim.keymap.set("n", keys, fn, { buffer = bufnr, desc = "Git: " .. desc })
			end
			map("]h", gs.next_hunk, "Next hunk")
			map("[h", gs.prev_hunk, "Prev hunk")
			map("<leader>gp", gs.preview_hunk, "Preview hunk")
			map("<leader>gr", gs.reset_hunk, "Reset hunk")
			map("<leader>gb", gs.blame_line, "Blame line")
			map("<leader>gd", gs.diffthis, "Diff this")
		end,
	},
}
