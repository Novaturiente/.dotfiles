-- ============================================================================
-- SUPERMAVEN: fast AI inline tab-completion (ghost-text)
-- ============================================================================
-- First run: execute :SupermavenUseFree once (no account needed).
-- <Tab> accept suggestion · <C-Right> accept one word · <C-]> dismiss
return {
	"supermaven-inc/supermaven-nvim",
	event = "InsertEnter",
	keys = {
		{
			"<leader>at",
			function()
				require("supermaven-nvim.api").toggle()
			end,
			desc = "Toggle Supermaven (AI)",
		},
	},
	opts = {
		keymaps = {
			accept_suggestion = "<Tab>",
			accept_word = "<C-Right>",
			clear_suggestion = "<C-]>",
		},
		ignore_filetypes = { "snacks_dashboard", "TelescopePrompt", "NvimTree" },
		color = {
			suggestion_color = "#6c7086", -- catppuccin overlay0 (dim grey)
			cterm = 244,
		},
		log_level = "off",
		disable_inline_completion = false,
		disable_keymaps = false,
	},
}
