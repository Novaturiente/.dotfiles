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
	-- COLORSCHEME
	-- ========================================================================

	-- Tokyonight: Clean and modern colorscheme
	{
		"folke/tokyonight.nvim",
		priority = 1000, -- Load before other plugins
	},
	{
		"rose-pine/neovim",
		priority = 1000, -- Load before other plugins
	},
	{
		"vague-theme/vague.nvim",
		lazy = false, -- make sure we load this during startup if it is your main colorscheme
		priority = 1000, -- make sure to load this before all the other plugins
	},
	{
		"yorumicolors/yorumi.nvim",
		priority = 1000, -- make sure to load this before all the other plugins
	},

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
				{ "<leader>f", group = "Search", icon = "󰜏" },
				{ "<leader>t", group = "Terminal" },
				{ "<leader>g", group = "Git", mode = { "n", "v" } },
				{ "<leader>r", group = "Run", icon = "" },
				{ "<leader>rs", group = "Run with sudo", icon = "" },
				{ "<leader>rb", group = "Build" },
				{ "<leader>q", group = "Exit" },
				{ "<leader>m", group = "Message", icon = "󱥁" },
				{ "<leader>e", desc = "File explorer", icon = "󰙅" },
			},
		},
	},

	-- NOICE NVIM
	{
		"folke/noice.nvim",
		event = "VeryLazy",
		dependencies = {
			"MunifTanjim/nui.nvim",
			{
				-- Notification system (required by noice)
				"rcarriga/nvim-notify",
				opts = {
					top_down = false, -- Show notifications from bottom to top
					timeout = 1000,
					-- Custom stage that removes borders
					stages = "fade_in_slide_out",
					render = "compact",
				},
			},
		},
		opts = {
			cmdline = {
				enabled = true,
				view = "cmdline_popup", -- Shows command line in a popup
				opts = {
					position = {
						row = "80%",
						col = "50%",
					},
					size = {
						width = 100,
						height = "auto",
					},
					border = {
						style = "rounded",
					},
					win_options = {
						winhighlight = "NormalFloat:NormalFloat,FloatBorder:FloatBorder",
					},
				},
			},
			messages = {
				enabled = true,
				view = "notify",
				view_error = "notify",
				view_warn = "notify",
			},
			popupmenu = {
				enabled = false,
			},
			presets = {
				bottom_search = true,
				command_palette = true,
				long_message_to_split = true,
			},
			lsp = {
				override = {
					["vim.lsp.util.convert_input_to_markdown_lines"] = true,
					["vim.lsp.util.stylize_markdown"] = true,
				},
			},
			notify = {
				enabled = true,
				view = "notify",
			},
			views = {
				popupmenu = {
					position = {
						row = "75%",
						col = "50%",
					},
					size = {
						width = 100,
						height = 10,
					},
					border = {
						padding = { 1, 2 },
					},
					win_options = {
						winhighlight = { Normal = "Normal", FloatBorder = "DiagnosticInfo" },
					},
				},
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
			{
				"nvim-telescope/telescope-file-browser.nvim",
			},
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
				pickers = {
					find_files = {
						hidden = true,
						file_ignore_patterns = { ".git/", ".cache/", ".local/" },
					},
				},
				extensions = {
					["ui-select"] = { require("telescope.themes").get_dropdown() },
					file_browser = {
						hidden = { file_browser = true, folder_browser = true },
						respect_gitignore = false,
						grouped = true,
						file_ignore_patterns = { "^.git/" },
					},
				},
			})
			-- Load extensions
			pcall(require("telescope").load_extension, "fzf")
			pcall(require("telescope").load_extension, "ui-select")
			pcall(require("telescope").load_extension, "file_browser")
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
			-- Define custom LSP configuration for KDL
			local lspconfig = require("lspconfig")
			local lspconfig_configs = require("lspconfig.configs")
			-- Register kdl-lsp if not already registered
			if not lspconfig_configs.kdl_lsp then
				lspconfig_configs.kdl_lsp = {
					default_config = {
						cmd = { "kdl-lsp" }, -- Assumes kdl-lsp is in PATH
						filetypes = { "kdl" },
						root_dir = lspconfig.util.root_pattern(".git", vim.fn.getcwd()),
						settings = {},
					},
				}
			end
			-- Define LSP servers and their settings
			local servers = {
				lua_ls = {
					settings = { Lua = { completion = { callSnippet = "Replace" } } },
				},
				pyright = {},
				rust_analyzer = {},
				gopls = {},
				bashls = {},
			}
			-- Add foldingRange capability for nvim-ufo
			capabilities.textDocument.foldingRange = {
				dynamicRegistration = false,
				lineFoldingOnly = true,
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
				"python",
				"rust",
				"go",
				"yaml",
				"toml",
				"kdl",
				"json",
			},
			auto_install = true, -- Automatically install missing parsers
			ignore_install = { "org" },
		},
	},

	-- ============================================================================
	-- CONFORM.NVIM - CODE FORMATTING
	-- ============================================================================
	{
		"stevearc/conform.nvim",
		event = "BufWritePre",
		cmd = "ConformInfo",
		opts = {
			notify_on_error = true, -- Changed to true for debugging
			format_on_save = function(bufnr)
				-- Disable auto-format for C/C++ files
				local disable_filetypes = { c = true, cpp = true }
				if disable_filetypes[vim.bo[bufnr].filetype] then
					return
				end
				return {
					timeout_ms = 2000, -- Increased timeout
					lsp_fallback = true, -- Fixed: was lsp_format
				}
			end,
			formatters_by_ft = {
				lua = { "stylua" },
				python = { "ruff_organize_imports", "ruff_format" },
				rust = { "rustfmt" },
				bash = { "shfmt" },
				sh = { "shfmt" },
				yaml = { "prettier" },
				toml = { "taplo" },
				json = { "prettier" },
				jsonc = { "prettier" },
			},
		},
	},

	-- ============================================================================
	-- BETTER PYTHON INDENTATION
	-- ============================================================================
	{
		"Vimjas/vim-python-pep8-indent",
		ft = "python",
	},

	-- ============================================================================
	-- INDENT GUIDES
	-- ============================================================================
	{
		"lukas-reineke/indent-blankline.nvim",
		main = "ibl",
		opts = {
			indent = {
				char = "│",
			},
			whitespace = {
				highlight = { "Whitespace" },
			},
			scope = { enabled = false },
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
			"folke/lazydev.nvim",
		},
		--- @module 'blink.cmp'
		--- @type blink.cmp.Config
		opts = {
			keymap = {
				preset = "super-tab",
			},
			appearance = {
				nerd_font_variant = "mono",
			},
			completion = {
				list = { selection = { preselect = false } },
				menu = {
					auto_show = true,
				},
				ghost_text = { enabled = true },
			},
			cmdline = {
				keymap = { preset = "super-tab" },
				completion = { menu = { auto_show = true } },
			},
			sources = {
				default = { "lsp", "path", "snippets", "lazydev", "buffer" },
				providers = {
					lazydev = { module = "lazydev.integrations.blink", score_offset = 100 },
				},
			},
			fuzzy = { implementation = "prefer_rust" },
			signature = { enabled = true },
		},
	},

	-- ========================================================================
	-- AUTO-PAIRING
	-- ========================================================================

	-- Automatically insert matching closing characters for brackets, quotes, etc.
	{
		"windwp/nvim-autopairs",
		event = "InsertEnter",
		config = function()
			require("nvim-autopairs").setup({
				check_ts = true, -- Enable treesitter integration
				ts_config = {
					lua = { "string" }, -- Don't add pairs in lua string treesitter nodes
					javascript = { "template_string" },
					java = false, -- Don't check treesitter on java
				},
			})
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

	-- ============================================================================
	-- ORG MODE CONFIGURATION
	-- ============================================================================

	{
		"nvim-orgmode/orgmode",
		event = "VeryLazy",
		ft = { "org" },
		config = function()
			require("orgmode").setup({
				org_agenda_files = "~/Org/**/*",
				org_default_notes_file = "~/Org/refile.org",
			})
		end,
	},
	{
		"nvim-orgmode/org-bullets.nvim",
		dependencies = { "nvim-orgmode/orgmode" },
		ft = { "org" },
		config = function()
			require("org-bullets").setup()
		end,
	},
	{
		"nvim-orgmode/telescope-orgmode.nvim",
		event = "VeryLazy",
		dependencies = {
			"nvim-orgmode/orgmode",
			"nvim-telescope/telescope.nvim",
		},
		config = function()
			require("telescope").load_extension("orgmode")
		end,
	},
	{
		"lukas-reineke/headlines.nvim",
		dependencies = "nvim-treesitter/nvim-treesitter",
		config = true, -- or `opts = {}`
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
			require("mini.move").setup()
			-- Minimal statusline
			local statusline = require("mini.statusline")
			statusline.setup({ use_icons = vim.g.have_nerd_font })
			statusline.section_location = function()
				return "%2l:%-2v"
			end
		end,
	},

	-- ========================================================================
	-- FILE MANAGEMENT
	-- ========================================================================

	-- Oil.nvim: Edit your filesystem like a normal Neovim buffer
	{
		"stevearc/oil.nvim",
		---@module 'oil'
		---@type oil.SetupOpts
		opts = {},
		dependencies = { { "nvim-mini/mini.icons", opts = {} } },
		lazy = false,
		config = function()
			require("oil").setup({
				default_file_explorer = true,
				delete_to_trash = true,
				skip_confirm_for_simple_edits = true,
				prompt_save_on_select_new_entry = true,
				constrain_cursor = "editable",
				watch_for_changes = false,
				keymaps = {
					["."] = { "actions.open_cwd", mode = "n" },
				},
				-- use_default_keymaps = true,
				view_options = {
					-- Hide hidden files by default
					show_hidden = false,
					-- This function defines what is considered a "hidden" file
					-- Return false for files you want to show, true for files to hide
					is_hidden_file = function(name, bufnr)
						-- Whitelist specific hidden folders/files you want to see
						local whitelist = {
							".github",
							".gitignore",
							".env.example",
							".config",
							".dotfiles",
							".zshrc",
							".tmux.conf",
						}
						if vim.tbl_contains(whitelist, name) then
							return false
						end
						return vim.startswith(name, ".")
					end,
					is_always_hidden = function(name, bufnr)
						return vim.tbl_contains({
							"go",
						}, name)
					end,
				},
			})
		end,
	},

	-- ============================================================================
	-- VIRTUAL ENVIRONMENT SELECTOR (PYTHON)
	-- ============================================================================

	{
		"linux-cultist/venv-selector.nvim",
		dependencies = {
			"neovim/nvim-lspconfig",
			{ "nvim-telescope/telescope.nvim", branch = "0.1.x", dependencies = { "nvim-lua/plenary.nvim" } }, -- optional: you can also use fzf-lua, snacks, mini-pick instead.
		},
		ft = "python", -- Load when opening Python files
		keys = {
			{ "ev", "<cmd>VenvSelect<cr>" }, -- Open picker on keymap
		},
		opts = { -- this can be an empty lua table - just showing below for clarity.
			search = { cwd = false },
			options = {}, -- if you add plugin options, they go here.
		},
	},

	-- ============================================================================
	-- DASHBOARD
	-- ============================================================================

	{
		"goolord/alpha-nvim",
		-- dependencies = { 'echasnovski/mini.icons' },
		dependencies = { "nvim-tree/nvim-web-devicons" },
		config = function()
			local startify = require("alpha.themes.startify")
			startify.file_icons.provider = "devicons"
			require("alpha").setup(startify.config)
		end,
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
