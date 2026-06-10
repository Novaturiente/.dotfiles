-- ============================================================================
-- MINI: small editing helpers (pairs, text objects, surround)
-- ============================================================================
return {
	"echasnovski/mini.nvim",
	event = "VeryLazy",
	config = function()
		require("mini.pairs").setup() -- auto-close brackets/quotes
		require("mini.ai").setup({ n_lines = 500 }) -- better a/i text objects
		require("mini.surround").setup() -- sa/sd/sr to add/delete/replace surround
	end,
}
