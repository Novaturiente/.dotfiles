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
		config = function()
			require("tokyonight").setup({ styles = { comments = { italic = false } } })
			vim.cmd.colorscheme("tokyonight-night")
		end,
	},

	-- ========================================================================
	-- EVELOPMENT UTILITIES
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
			{
				"nvim-telescope/telescope-file-browser.nvim",
				config = function()
					require("telescope").setup({
						extensions = {
							file_browser = {
								hidden = { file_browser = true, folder_browser = true },
								respect_gitignore = false,
								grouped = true,
								-- Optional: exclude .git directory
								file_ignore_patterns = { "^.git/" },
							},
						},
					})

					-- Load the extension
					require("telescope").load_extension("file_browser")
				end,
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
				extensions = { ["ui-select"] = { require("telescope.themes").get_dropdown() } },
			})
			-- Load extensions
			pcall(require("telescope").load_extension, "fzf")
			pcall(require("telescope").load_extension, "ui-select")

			pickers = {
				find_files = {
					hidden = true,
					-- Optional: exclude certain patterns
					file_ignore_patterns = { ".git/", ".cache/", ".local/" },
				},
			}
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
			},
			auto_install = true, -- Automatically install missing parsers
		},
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
				documentation = { auto_show = false, auto_show_delay_ms = 500 },
			},
			cmdline = {
				keymap = { preset = "inherit" },
				completion = { menu = { auto_show = true } },
			},
			sources = {
				default = { "lsp", "path", "snippets", "lazydev" },
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
	-- CODE FOLDING
	-- ============================================================================

	{
		"kevinhwang91/nvim-ufo",
		dependencies = "kevinhwang91/promise-async",
		event = "BufReadPost",
		config = function()
			-- Set fold options
			vim.o.foldcolumn = "1"
			vim.o.foldlevel = 99
			vim.o.foldlevelstart = 99
			vim.o.foldenable = true

			-- Setup ufo with treesitter provider
			require("ufo").setup({
				provider_selector = function(bufnr, filetype, buftype)
					return { "treesitter", "indent" }
				end,
			})

			-- Keymaps for folding
			vim.keymap.set("n", "zR", require("ufo").openAllFolds, { desc = "Open all folds" })
			vim.keymap.set("n", "zM", require("ufo").closeAllFolds, { desc = "Close all folds" })
			vim.keymap.set("n", "zK", require("ufo").peekFoldedLinesUnderCursor, { desc = "Peek folded lines" })
		end,
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
	-- MESSAGE UTILITIES
	-- ========================================================================
	-- Capture and show :messages in a customizable floating buffer
	{ "AckslD/messages.nvim", opts = {} },

	-- ============================================================================
	-- MESSAGE MANAGEMENT KEYMAPS
	-- ============================================================================

	-- Show messages in a new buffer (native method)
	vim.keymap.set("n", "<leader>M", function()
		vim.cmd("new")
		vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(vim.fn.execute("messages"), "\n"))
		vim.bo.buftype = "nofile"
		vim.bo.bufhidden = "wipe"
	end, { noremap = true, silent = true, desc = "Messages in new buffer" }),
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
