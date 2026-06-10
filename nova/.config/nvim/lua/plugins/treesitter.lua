-- ============================================================================
-- TREESITTER: syntax highlighting + indentation
-- ============================================================================
return {
	"nvim-treesitter/nvim-treesitter",
	branch = "master",
	build = ":TSUpdate",
	event = { "BufReadPost", "BufNewFile" },
	main = "nvim-treesitter.configs",
	opts = {
		ensure_installed = {
			"bash",
			"lua",
			"luadoc",
			"python",
			"rust",
			"go",
			"gomod",
			"json",
			"yaml",
			"toml",
			"markdown",
			"markdown_inline",
			"vim",
			"vimdoc",
			"diff",
		},
		auto_install = true,
		highlight = { enable = true },
		indent = { enable = true },
	},
}
