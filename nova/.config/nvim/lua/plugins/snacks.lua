-- ============================================================================
-- SNACKS: folke's modular QoL collection (only the modules below load)
-- ============================================================================
return {
	"folke/snacks.nvim",
	priority = 1000,
	lazy = false, -- start modules need to init early
	opts = {
		-- Start modules (tiny, load at startup)
		bigfile = { enabled = true }, -- disable heavy features on huge files
		quickfile = { enabled = true }, -- render file before plugins load
		statuscolumn = { enabled = true }, -- nicer fold/sign/number column
		words = { enabled = true }, -- jump LSP references with ]] [[

		-- Light / on-demand modules
		notifier = { enabled = true, timeout = 3000 }, -- clean notifications
		input = { enabled = true }, -- better vim.ui.input popup
		indent = { enabled = true }, -- indent guides + scope
		scope = { enabled = true }, -- scope textobjects/motions

		-- Pure on-demand (load on first keymap)
		lazygit = { enabled = true },
		terminal = { enabled = true },
		bufdelete = { enabled = true },
		scratch = { enabled = true },

		-- Dashboard (actions wired to telescope, since picker is disabled)
		dashboard = {
			enabled = true,
			preset = {
				keys = {
					{ icon = " ", key = "f", desc = "Find File", action = "<cmd>Telescope find_files<cr>" },
					{ icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
					{ icon = " ", key = "g", desc = "Live Grep", action = "<cmd>Telescope live_grep<cr>" },
					{ icon = " ", key = "r", desc = "Recent Files", action = "<cmd>Telescope oldfiles<cr>" },
					{ icon = " ", key = "e", desc = "File Explorer", action = "<cmd>NvimTreeToggle<cr>" },
					{
						icon = " ",
						key = "c",
						desc = "Config",
						action = "<cmd>lua require('telescope.builtin').find_files({cwd=vim.fn.stdpath('config')})<cr>",
					},
					{ icon = "󰒲 ", key = "L", desc = "Lazy", action = "<cmd>Lazy<cr>" },
					{ icon = " ", key = "m", desc = "Mason", action = "<cmd>Mason<cr>" },
					{ icon = " ", key = "q", desc = "Quit", action = ":qa" },
				},
			},
		},

		-- Explicitly off (telescope + nvim-tree already cover these)
		picker = { enabled = false },
		explorer = { enabled = false },
	},
	keys = {
		{ "<leader>gg", function() Snacks.lazygit() end, desc = "Lazygit" },
		{ "<leader>gl", function() Snacks.lazygit.log() end, desc = "Lazygit log" },
		{ "<leader>tt", function() Snacks.terminal.toggle() end, desc = "Terminal", mode = { "n", "t" } },
		{ "<leader>bd", function() Snacks.bufdelete() end, desc = "Delete buffer (keep layout)" },
		{ "<leader>.", function() Snacks.scratch() end, desc = "Toggle scratch buffer" },
		{ "<leader>nh", function() Snacks.notifier.show_history() end, desc = "Notification history" },
		{ "<leader>nd", function() Snacks.notifier.hide() end, desc = "Dismiss notifications" },
		{ "]]", function() Snacks.words.jump(1) end, desc = "Next reference" },
		{ "[[", function() Snacks.words.jump(-1) end, desc = "Prev reference" },
	},
	init = function()
		-- Route vim.notify through snacks once it loads
		vim.api.nvim_create_autocmd("User", {
			pattern = "VeryLazy",
			callback = function()
				vim.notify = require("snacks").notifier.notify
			end,
		})
	end,
}
