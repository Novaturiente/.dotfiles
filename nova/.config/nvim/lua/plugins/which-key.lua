-- ============================================================================
-- WHICH-KEY: leader menu (shows available keybindings on <leader>)
-- ============================================================================
return {
	"folke/which-key.nvim",
	event = "VeryLazy",
	opts = {
		preset = "modern",
		delay = 200,
		spec = {
			{ "<leader>f", group = "Find" },
			{ "<leader>g", group = "Git" },
			{ "<leader>l", group = "LSP" },
			{ "<leader>c", group = "Code" },
			{ "<leader>b", group = "Buffer" },
			{ "<leader>t", group = "Terminal" },
			{ "<leader>n", group = "Notifications" },
			{ "<leader>a", group = "AI" },
		},
	},
	keys = {
		{
			"<leader>?",
			function()
				require("which-key").show({ global = false })
			end,
			desc = "Buffer keymaps",
		},
	},
}
