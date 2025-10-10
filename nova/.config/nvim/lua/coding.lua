-- ============================================================================
-- PYTHON SPECIFIC CONFIGURATION
-- ============================================================================

vim.api.nvim_create_autocmd("FileType", {
	pattern = "python",
	callback = function()
		local buf = vim.api.nvim_get_current_buf()
		if vim.b[buf].python_mode_initialized then
			return
		end
		vim.b[buf].python_mode_initialized = true
		vim.bo.expandtab = true
		vim.bo.shiftwidth = 4
		vim.bo.tabstop = 4
		require("venv-selector").workspace_paths()
		require("venv-selector").file_dir()
		local file = vim.fn.expand("%:p")
		local function get_lsp_root()
			local clients = vim.lsp.get_clients({ bufnr = buf })
			for _, client in ipairs(clients) do
				if client.name == "pyright" then
					return client.config.root_dir
				end
			end
			-- Fallback: use workspace folders (works for most LSPs)
			local folders = vim.lsp.buf.list_workspace_folders()
			return folders[1]
		end
		vim.api.nvim_create_autocmd("LspAttach", {
			buffer = buf,
			callback = function()
				local root = get_lsp_root() or "Not detected"
				print("Python mode activated | Root: " .. root)

				vim.keymap.set("n", "<leader>rr", function()
					vim.cmd("vsplit")
					vim.cmd("lcd " .. root)
					vim.cmd("terminal uv run " .. file) -- Replace with your command
				end, { noremap = true, silent = true, desc = "Run file" })

				vim.keymap.set("n", "<leader>rsr", function()
					vim.cmd("vsplit")
					vim.cmd("lcd " .. root)
					vim.cmd("terminal sudo uv run " .. file) -- Replace with your command
				end, { noremap = true, silent = true, desc = "Sudo run file" })

				vim.keymap.set("n", "<leader>ra", function()
					vim.ui.input({ prompt = "Command to run: " }, function(cmd)
						if cmd then
							vim.cmd("vsplit")
							vim.cmd("lcd " .. root)
							vim.cmd("terminal uv run " .. file .. " " .. cmd)
						end
					end)
				end, { noremap = true, silent = true, desc = "Run file with arguments" })

				vim.keymap.set("n", "<leader>rsa", function()
					vim.ui.input({ prompt = "Command to run: " }, function(cmd)
						if cmd then
							vim.cmd("vsplit")
							vim.cmd("lcd " .. root)
							vim.cmd("terminal sudo uv run " .. file .. " " .. cmd)
						end
					end)
				end, { noremap = true, silent = true, desc = "Sudo run file with arguments" })
			end,
		})
	end,
})

-- ============================================================================
-- BASH CONFIGURATION
-- ============================================================================

vim.api.nvim_create_autocmd("FileType", {
	pattern = { "sh", "bash" },
	callback = function()
		vim.bo.expandtab = false
		vim.bo.shiftwidth = 4
		vim.bo.tabstop = 4
		local root = vim.fn.expand("%:p:h")
		local file = vim.fn.expand("%:p")

		vim.keymap.set("n", "<leader>rx", function()
			vim.cmd("!chmod +x %")
			print("File made executable")
		end, { noremap = true, silent = true, desc = "Run file" })

		vim.keymap.set("n", "<leader>rr", function()
			vim.cmd("vsplit")
			vim.cmd("lcd " .. root)
			vim.cmd("terminal " .. file) -- Replace with your command
		end, { noremap = true, silent = true, desc = "Run file" })

		vim.keymap.set("n", "<leader>rsr", function()
			vim.cmd("vsplit")
			vim.cmd("lcd " .. root)
			vim.cmd("terminal sudo " .. file) -- Replace with your command
		end, { noremap = true, silent = true, desc = "Sudo run file" })

		vim.keymap.set("n", "<leader>ra", function()
			vim.ui.input({ prompt = "Command to run: " }, function(cmd)
				if cmd then
					vim.cmd("vsplit")
					vim.cmd("lcd " .. root)
					vim.cmd("terminal " .. file .. " " .. cmd)
				end
			end)
		end, { noremap = true, silent = true, desc = "Run file with arguments" })

		vim.keymap.set("n", "<leader>rsa", function()
			vim.ui.input({ prompt = "Command to run: " }, function(cmd)
				if cmd then
					vim.cmd("vsplit")
					vim.cmd("lcd " .. root)
					vim.cmd("terminal sudo " .. file .. " " .. cmd)
				end
			end)
		end, { noremap = true, silent = true, desc = "Sudo run file with arguments" })
	end,
})

-- ============================================================================
-- RUST CONFIGURATION
-- ============================================================================

vim.api.nvim_create_autocmd("FileType", {
	pattern = "rust",
	callback = function()
		local buf = vim.api.nvim_get_current_buf()
		if vim.b[buf].rust_mode_initialized then
			return
		end
		vim.b[buf].rust_mode_initialized = true
		vim.bo.expandtab = true
		vim.bo.shiftwidth = 4
		vim.bo.tabstop = 4
		local function get_lsp_root()
			local clients = vim.lsp.get_clients({ bufnr = buf })
			for _, client in ipairs(clients) do
				if client.name == "rust-analyzer" then
					return client.config.root_dir
				end
			end
			-- Fallback: use workspace folders (works for most LSPs)
			local folders = vim.lsp.buf.list_workspace_folders()
			return folders[1]
		end
		vim.api.nvim_create_autocmd("LspAttach", {
			buffer = buf,
			callback = function()
				local root = get_lsp_root() or "Not detected"
				print("Rust mode activated | Root: " .. root)

				vim.keymap.set("n", "<leader>rr", function()
					vim.cmd("vsplit")
					vim.cmd("lcd " .. root)
					vim.cmd("terminal cargo run") -- Replace with your command
				end, { noremap = true, silent = true, desc = "Run file" })

				vim.keymap.set("n", "<leader>rsr", function()
					vim.cmd("vsplit")
					vim.cmd("lcd " .. root)
					vim.cmd("terminal sudo cargo run") -- Replace with your command
				end, { noremap = true, silent = true, desc = "Sudo run file" })

				vim.keymap.set("n", "<leader>ra", function()
					vim.ui.input({ prompt = "Command to run: " }, function(cmd)
						if cmd then
							vim.cmd("vsplit")
							vim.cmd("lcd " .. root)
							vim.cmd("terminal cargo run -- " .. cmd)
						end
					end)
				end, { noremap = true, silent = true, desc = "Run file with arguments" })

				vim.keymap.set("n", "<leader>rsa", function()
					vim.ui.input({ prompt = "Command to run: " }, function(cmd)
						if cmd then
							vim.cmd("vsplit")
							vim.cmd("lcd " .. root)
							vim.cmd("terminal sudo cargo run -- " .. cmd)
						end
					end)
				end, { noremap = true, silent = true, desc = "Sudo run file with arguments" })

				vim.keymap.set("n", "<leader>rbb", function()
					vim.cmd("vsplit")
					vim.cmd("lcd " .. root)
					vim.cmd("terminal cargo build") -- Replace with your command
				end, { noremap = true, silent = true, desc = "Build file" })

				vim.keymap.set("n", "<leader>rbr", function()
					vim.cmd("vsplit")
					vim.cmd("lcd " .. root)
					vim.cmd("terminal cargo build --release") -- Replace with your command
				end, { noremap = true, silent = true, desc = "Build relese file" })
			end,
		})
	end,
})

-- ============================================================================
-- GO CONFIGURATION
-- ============================================================================

vim.api.nvim_create_autocmd("FileType", {
	pattern = "go",
	callback = function()
		local buf = vim.api.nvim_get_current_buf()
		if vim.b[buf].go_mode_initialized then
			return
		end
		vim.b[buf].go_mode_initialized = true
		vim.bo.expandtab = true
		vim.bo.shiftwidth = 4
		vim.bo.tabstop = 4
		local function get_lsp_root()
			local clients = vim.lsp.get_clients({ bufnr = buf })
			for _, client in ipairs(clients) do
				if client.name == "gopls" then
					return client.config.root_dir
				end
			end
			-- Fallback: use workspace folders (works for most LSPs)
			local folders = vim.lsp.buf.list_workspace_folders()
			return folders[1]
		end
		vim.api.nvim_create_autocmd("LspAttach", {
			buffer = buf,
			callback = function()
				local root = get_lsp_root() or "Not detected"
				print("Go mode activated | Root: " .. root)

				vim.keymap.set("n", "<leader>rr", function()
					vim.cmd("vsplit")
					vim.cmd("lcd " .. root)
					vim.cmd("terminal go run .") -- Replace with your command
				end, { noremap = true, silent = true, desc = "Run file" })

				vim.keymap.set("n", "<leader>rsr", function()
					vim.cmd("vsplit")
					vim.cmd("lcd " .. root)
					vim.cmd("terminal sudo go run .") -- Replace with your command
				end, { noremap = true, silent = true, desc = "Sudo run file" })

				vim.keymap.set("n", "<leader>ra", function()
					vim.ui.input({ prompt = "Command to run: " }, function(cmd)
						if cmd then
							vim.cmd("vsplit")
							vim.cmd("lcd " .. root)
							vim.cmd("terminal go run " .. cmd)
						end
					end)
				end, { noremap = true, silent = true, desc = "Run file with arguments" })

				vim.keymap.set("n", "<leader>rsa", function()
					vim.ui.input({ prompt = "Command to run: " }, function(cmd)
						if cmd then
							vim.cmd("vsplit")
							vim.cmd("lcd " .. root)
							vim.cmd("terminal sudo go run " .. cmd)
						end
					end)
				end, { noremap = true, silent = true, desc = "Sudo run file with arguments" })

				vim.keymap.set("n", "<leader>rbb", function()
					vim.cmd("vsplit")
					vim.cmd("lcd " .. root)
					vim.cmd("terminal go build") -- Replace with your command
				end, { noremap = true, silent = true, desc = "Build file" })
			end,
		})
	end,
})
-- ============================================================================
-- HEADER CONFIGURATION
-- ============================================================================
vim.api.nvim_create_autocmd("BufNewFile", {
	pattern = { "*.py", "*.sh", "*.rs", "*.go", "*.js" },
	callback = function()
		local ft = vim.bo.filetype
		local filename = vim.fn.expand("%:t")
		local header = {}

		if ft == "python" then
			header = {
				"# File: " .. filename,
				"# Author: " .. (os.getenv("USER") or "unknown"),
				"# Created: " .. os.date("%Y-%m-%d %H:%M:%S"),
				"",
			}
		elseif ft == "sh" then
			header = {
				"#!/usr/bin/env bash",
				"#",
				"# File: " .. filename,
				"# Author: " .. (os.getenv("USER") or "unknown"),
				"# Created: " .. os.date("%Y-%m-%d %H:%M:%S"),
				"",
			}
		elseif ft == "rust" then
			header = {
				"// File: " .. filename,
				"// Author: " .. (os.getenv("USER") or "unknown"),
				"// Created: " .. os.date("%Y-%m-%d %H:%M:%S"),
				"",
			}
		end

		-- Insert lines only if file is empty
		if vim.fn.line("$") == 1 and vim.fn.getline(1) == "" then
			vim.api.nvim_buf_set_lines(0, 0, -1, false, header)
		end
	end,
})
