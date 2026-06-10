-- ============================================================================
-- COMPLETION: blink.cmp (fast, single plugin)
-- ============================================================================
return {
	"saghen/blink.cmp",
	event = { "InsertEnter", "CmdlineEnter" },
	version = "1.*", -- prebuilt fuzzy binary
	opts = {
		-- 'default' frees <Tab> for Supermaven AI ghost-text.
		-- Menu: <C-y> accept, <C-n>/<C-p> navigate, <C-space> show.
		keymap = { preset = "default" },
		appearance = { nerd_font_variant = "mono" },
		completion = {
			documentation = { auto_show = true },
			ghost_text = { enabled = false }, -- off: Supermaven owns inline ghost
		},
		sources = {
			default = { "lsp", "path", "snippets", "buffer" },
		},
		-- Completion + suggestions while typing in the ":" command line
		cmdline = {
			keymap = { preset = "cmdline" }, -- Tab/arrows to pick, Enter to run
			completion = {
				menu = { auto_show = true }, -- show popup automatically
				ghost_text = { enabled = true }, -- inline suggestion preview
			},
		},
		fuzzy = { implementation = "prefer_rust" },
		signature = { enabled = true },
	},
}
