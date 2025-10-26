-- ============================================================================
-- NEOVIM PLUGIN CONFIGURATION
-- ============================================================================
return {
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
		event = "VeryLazy",
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
				{ "<leader>r", group = "Run", icon = "" },
				{ "<leader>rs", group = "Run with sudo", icon = "" },
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
			indent = {
				enable = true,
			},
			highlight = { enable = true },
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
			auto_install = true,
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
				kdl = { "kdlfmt" },
			},
		},
	},

	-- ========================================================================
	-- DIAGNOSTICS & TROUBLE
	-- ========================================================================
	{
		"folke/trouble.nvim",
		cmd = "Trouble",
		opts = {
			auto_close = true,
			focus = true,
		}, -- Uses default configuration
	},

	-- ============================================================================
	-- INDENTATION
	-- ============================================================================

	{
		"NMAC427/guess-indent.nvim",
		config = function()
			require("guess-indent").setup({})
		end,
	},
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

	-- ========================================================================
	-- CODE NAVIGATION
	-- ========================================================================

	-- Outline: Code outline window for viewing and jumping to symbols
	{
		"hedyhli/outline.nvim",
		lazy = true,
		cmd = { "Outline", "OutlineOpen" },
		keys = {
			{ "<leader>mm", "<cmd>Outline<CR>", desc = "Toggle outline" },
		},
		config = function()
			require("outline").setup({
				outline_window = {
					position = "right", -- Right side positioning
					width = 25,
					relative_width = true,
					auto_close = false,
					auto_jump = false,
					focus_on_open = true,
					show_numbers = false,
					show_relative_numbers = false,
				},
				outline_items = {
					show_symbol_details = true,
					show_symbol_lineno = true, -- Show line numbers
					highlight_hovered_item = true,
					auto_set_cursor = true,
				},
				symbol_folding = {
					autofold_depth = 1,
					auto_unfold = {
						hovered = true,
					},
				},
				preview_window = {
					auto_preview = false, -- Set true for auto preview
				},
				symbols = {
					icons = {
						File = { icon = "󰈔", hl = "Identifier" },
						Module = { icon = "󰆧", hl = "Include" },
						Namespace = { icon = "󰅪", hl = "Include" },
						Package = { icon = "󰏗", hl = "Include" },
						Class = { icon = "𝓒", hl = "Type" },
						Method = { icon = "ƒ", hl = "Function" },
						Property = { icon = "", hl = "Identifier" },
						Field = { icon = "󰆨", hl = "Identifier" },
						Constructor = { icon = "", hl = "Special" },
						Enum = { icon = "ℰ", hl = "Type" },
						Interface = { icon = "󰜰", hl = "Type" },
						Function = { icon = "", hl = "Function" },
						Variable = { icon = "", hl = "Constant" },
					},
				},
			})
		end,
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
		event = "VeryLazy",
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
	-- FILE MANAGEMENT
	-- ========================================================================

	{
		"stevearc/oil.nvim",
		opts = {},
		dependencies = { { "nvim-tree/nvim-web-devicons", opts = {} } },
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
				view_options = {
					show_hidden = false,
					is_hidden_file = function(name, bufnr)
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
						return vim.tbl_contains({ "go" }, name)
					end,
				},
				float = {
					padding = 2,
					max_width = 80,
					max_height = 30,
					border = "rounded",
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
	{
		"NStefan002/speedtyper.nvim",
		branch = "v2",
		lazy = false,
	},
}
