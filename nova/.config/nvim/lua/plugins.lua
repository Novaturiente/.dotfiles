-- ============================================================================
-- NEOVIM PLUGIN CONFIGURATION
-- ============================================================================
-- This file manages all Neovim plugins using lazy.nvim plugin manager.
-- Lazy.nvim provides fast startup times through automatic caching and
-- lazy-loading capabilities.
-- ============================================================================

-- ============================================================================
-- LAZY.NVIM BOOTSTRAP
-- ============================================================================
-- Automatically install lazy.nvim if not present
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
	if vim.v.shell_error ~= 0 then
		error("Error cloning lazy.nvim:\n" .. out)
	end
end
vim.opt.rtp:prepend(lazypath)

-- ============================================================================
-- PLUGIN SPECIFICATIONS
-- ============================================================================

require("lazy").setup({
	-- ========================================================================
	-- DEVELOPMENT UTILITIES
	-- ========================================================================

	-- Hot reload: Automatically reload Neovim config on file changes
	{ "Zeioth/hot-reload.nvim", dependencies = "nvim-lua/plenary.nvim", event = "BufEnter", opts = {} },

	-- Automatically detect and set indentation based on file content
	"NMAC427/guess-indent.nvim",

	-- ========================================================================
	-- GIT INTEGRATION
	-- ========================================================================

	-- Gitsigns: Show git diff indicators in the sign column
	{
		"lewis6991/gitsigns.nvim",
		opts = {
			signs = {
				add = { text = "+" },
				change = { text = "~" },
				delete = { text = "_" },
				topdelete = { text = "‾" },
				changedelete = { text = "~" },
			},
		},
	},

	{
		"NeogitOrg/neogit",
		dependencies = {
			"nvim-lua/plenary.nvim", -- required
			"sindrets/diffview.nvim", -- optional - Diff integration

			-- Only one of these is needed.
			"nvim-telescope/telescope.nvim", -- optional
		},
	},

	-- ========================================================================
	-- USER INTERFACE ENHANCEMENTS
	-- ========================================================================

	-- Which-key: Display pending keybindings in a popup
	{
		"folke/which-key.nvim",
		event = "VimEnter",
		opts = {
			delay = 100, -- Delay before showing popup (ms)
			icons = {
				mappings = vim.g.have_nerd_font,
				-- Fallback key icons when Nerd Font is not available
				keys = vim.g.have_nerd_font and {} or {
					Up = "<Up> ",
					Down = "<Down> ",
					Left = "<Left> ",
					Right = "<Right> ",
					C = "<C-…> ",
					M = "<M-…> ",
					D = "<D-…> ",
					S = "<S-…> ",
					CR = "<CR> ",
					Esc = "<Esc> ",
					NL = "<NL> ",
					BS = "<BS> ",
					Space = "<Space> ",
					Tab = "<Tab> ",
					F1 = "<F1>",
					F2 = "<F2>",
					F3 = "<F3>",
					F4 = "<F4>",
					F5 = "<F5>",
					F6 = "<F6>",
					F7 = "<F7>",
					F8 = "<F8>",
					F9 = "<F9>",
					F10 = "<F10>",
					F11 = "<F11>",
					F12 = "<F12>",
				},
			},
			spec = {
				{ "<leader>s", group = "[S]earch" },
				{ "<leader>t", group = "[T]oggle" },
				{ "<leader>h", group = "Git [H]unk", mode = { "n", "v" } },
			},
		},
	},

	-- ========================================================================
	-- FUZZY FINDER
	-- ========================================================================

	-- Telescope: Highly extendable fuzzy finder for files, text, and more
	{
		"nvim-telescope/telescope.nvim",
		event = "VimEnter",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-telescope/telescope-file-browser.nvim",
			{
				"nvim-telescope/telescope-fzf-native.nvim",
				build = "make",
				cond = function()
					return vim.fn.executable("make") == 1
				end,
			},
			"nvim-telescope/telescope-ui-select.nvim",
			{ "nvim-tree/nvim-web-devicons", enabled = vim.g.have_nerd_font },
		},
		config = function()
			require("telescope").setup({
				extensions = { ["ui-select"] = { require("telescope.themes").get_dropdown() } },
			})
			-- Load extensions
			pcall(require("telescope").load_extension, "fzf")
			pcall(require("telescope").load_extension, "ui-select")
		end,
	},

	-- ========================================================================
	-- LSP (LANGUAGE SERVER PROTOCOL)
	-- ========================================================================

	-- Lazydev: Enhanced Lua development for Neovim config files
	{
		"folke/lazydev.nvim",
		ft = "lua",
		opts = { library = { { path = "${3rd}/luv/library", words = { "vim%.uv" } } } },
	},

	-- LSP Configuration: Provides IDE-like features
	{
		"neovim/nvim-lspconfig",
		dependencies = {
			{ "mason-org/mason.nvim", opts = {} }, -- Package manager for LSP servers
			"mason-org/mason-lspconfig.nvim",
			"WhoIsSethDaniel/mason-tool-installer.nvim",
			{ "j-hui/fidget.nvim", opts = {} }, -- LSP progress notifications
			"saghen/blink.cmp",
		},
		config = function()
			-- LSP keybindings are defined in separate keybindings file
			vim.api.nvim_create_autocmd("LspAttach", {
				group = vim.api.nvim_create_augroup("kickstart-lsp-attach", { clear = true }),
				callback = function(event) end,
			})

			-- Configure diagnostic display
			vim.diagnostic.config({
				severity_sort = true,
				float = { border = "rounded", source = "if_many" },
				underline = { severity = vim.diagnostic.severity.ERROR },
				signs = vim.g.have_nerd_font and {
					text = {
						[vim.diagnostic.severity.ERROR] = "󰅚 ",
						[vim.diagnostic.severity.WARN] = "󰀪 ",
						[vim.diagnostic.severity.INFO] = "󰋽 ",
						[vim.diagnostic.severity.HINT] = "󰌶 ",
					},
				} or {},
				virtual_text = {
					source = "if_many",
					spacing = 2,
					format = function(diagnostic)
						return diagnostic.message
					end,
				},
			})

			-- Get LSP capabilities from completion plugin
			local capabilities = require("blink.cmp").get_lsp_capabilities()

			-- Define LSP servers and their settings
			local servers = {
				lua_ls = {
					settings = { Lua = { completion = { callSnippet = "Replace" } } },
				},
			}

			-- Install tools automatically
			local ensure_installed = vim.tbl_keys(servers or {})
			vim.list_extend(ensure_installed, { "stylua" })
			require("mason-tool-installer").setup({ ensure_installed = ensure_installed })

			-- Setup LSP servers
			require("mason-lspconfig").setup({
				ensure_installed = {},
				automatic_installation = false,
				handlers = {
					function(server_name)
						local server = servers[server_name] or {}
						server.capabilities = vim.tbl_deep_extend("force", {}, capabilities, server.capabilities or {})
						require("lspconfig")[server_name].setup(server)
					end,
				},
			})
		end,
	},

	-- ========================================================================
	-- CODE FORMATTING
	-- ========================================================================

	-- Conform: Lightweight formatter with format-on-save support
	{
		"stevearc/conform.nvim",
		event = "BufWritePre",
		cmd = "ConformInfo",
		opts = {
			notify_on_error = false,
			format_on_save = function(bufnr)
				-- Disable auto-format for C/C++ files
				local disable_filetypes = { c = true, cpp = true }
				return disable_filetypes[vim.bo[bufnr].filetype] and nil
					or { timeout_ms = 500, lsp_format = "fallback" }
			end,
			formatters_by_ft = {
				lua = { "stylua" },
				python = { "isort", "black" },
			},
		},
	},

	-- ========================================================================
	-- AUTOCOMPLETION
	-- ========================================================================

	-- Blink.cmp: Fast and feature-rich completion engine
	{
		"saghen/blink.cmp",
		event = "VimEnter",
		version = "1.*",
		dependencies = {
			{
				"L3MON4D3/LuaSnip",
				version = "2.*",
				build = (function()
					if vim.fn.has("win32") == 1 or vim.fn.executable("make") == 0 then
						return
					end
					return "make install_jsregexp"
				end)(),
				opts = {},
			},
			"folke/lazydev.nvim",
		},
		opts = {
			keymap = { preset = "super-tab" }, -- Use Tab for completion navigation
			appearance = { nerd_font_variant = "mono" },
			completion = { documentation = { auto_show = false, auto_show_delay_ms = 500 } },
			sources = {
				default = { "lsp", "path", "snippets", "lazydev" },
				providers = { lazydev = { module = "lazydev.integrations.blink", score_offset = 100 } },
			},
			snippets = { preset = "luasnip" },
			fuzzy = { implementation = "prefer_rust" },
			signature = { enabled = true },
		},
	},

	-- ========================================================================
	-- COLORSCHEME
	-- ========================================================================

	-- Tokyonight: Clean and modern colorscheme
	{
		"folke/tokyonight.nvim",
		priority = 1000, -- Load before other plugins
		config = function()
			require("tokyonight").setup({ styles = { comments = { italic = false } } })
			vim.cmd.colorscheme("tokyonight-night")
		end,
	},

	-- ========================================================================
	-- CODE ANNOTATIONS
	-- ========================================================================

	-- Todo Comments: Highlight TODO, FIXME, NOTE, etc. in comments
	{
		"folke/todo-comments.nvim",
		event = "VimEnter",
		dependencies = "nvim-lua/plenary.nvim",
		opts = { signs = false },
	},

	-- ========================================================================
	-- MINI PLUGINS
	-- ========================================================================

	-- Mini.nvim: Collection of small, independent plugins
	{
		"echasnovski/mini.nvim",
		config = function()
			-- Better text objects (e.g., va), yinq, ci')
			require("mini.ai").setup({ n_lines = 500 })

			-- Surround operations (e.g., saiw), sd', sr)')
			require("mini.surround").setup()

			-- Minimal statusline
			local statusline = require("mini.statusline")
			statusline.setup({ use_icons = vim.g.have_nerd_font })
			statusline.section_location = function()
				return "%2l:%-2v"
			end
		end,
	},

	-- ========================================================================
	-- SYNTAX HIGHLIGHTING
	-- ========================================================================

	-- Treesitter: Advanced syntax highlighting and code understanding
	{
		"nvim-treesitter/nvim-treesitter",
		build = ":TSUpdate",
		main = "nvim-treesitter.configs",
		opts = {
			ensure_installed = {
				"bash",
				"c",
				"diff",
				"html",
				"lua",
				"luadoc",
				"markdown",
				"markdown_inline",
				"query",
				"vim",
				"vimdoc",
			},
			auto_install = true, -- Automatically install missing parsers
			highlight = { enable = true, additional_vim_regex_highlighting = { "ruby" } },
			indent = { enable = true, disable = { "ruby" } },
		},
	},
}, {
	-- ========================================================================
	-- LAZY.NVIM UI CONFIGURATION
	-- ========================================================================
	ui = {
		icons = vim.g.have_nerd_font and {} or {
			cmd = "⌘",
			config = "🛠",
			event = "📅",
			ft = "📂",
			init = "⚙",
			keys = "🗝",
			plugin = "🔌",
			runtime = "💻",
			require = "🌙",
			source = "📄",
			start = "🚀",
			task = "📌",
			lazy = "💤 ",
		},
	},
})
