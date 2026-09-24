-- ============================================================================
-- MARKDOWN: in-buffer rendering + org-style heading folds
-- Cursor line and insert mode show raw text (render-markdown's anti-conceal).
-- <Tab> folds the section under the cursor, <S-Tab> folds/unfolds everything.
-- ============================================================================
return {
	"MeanderingProgrammer/render-markdown.nvim",
	ft = "markdown",
	dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
	opts = {},
	keys = {
		{ "<leader>um", "<cmd>RenderMarkdown buf_toggle<cr>", ft = "markdown", desc = "Toggle markdown render" },
	},
	-- init, not config: the autocmd must exist before the first markdown buffer loads the plugin.
	init = function()
		vim.api.nvim_create_autocmd("FileType", {
			group = vim.api.nvim_create_augroup("markdown_folds", { clear = true }),
			pattern = "markdown",
			callback = function(args)
				vim.opt_local.foldmethod = "expr"
				vim.opt_local.foldexpr = "v:lua.vim.treesitter.foldexpr()"
				vim.keymap.set("n", "<Tab>", "za", { buffer = args.buf, desc = "Toggle section fold" })
				-- ponytail: two states (all folded / all open), not org's three-step overview/contents/all cycle
				vim.keymap.set("n", "<S-Tab>", function()
					vim.cmd.normal({ vim.wo.foldlevel > 0 and "zM" or "zR", bang = true })
				end, { buffer = args.buf, desc = "Fold/unfold all sections" })
			end,
		})
	end,
}
