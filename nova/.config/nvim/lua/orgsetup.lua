-- ============================================================================
-- ORG MODE - CONCEALMENT SETTINGS
-- ============================================================================

-- Enable link concealment for org files (show only description)
vim.api.nvim_create_autocmd("FileType", {
	pattern = "org",
	callback = function()
		vim.opt_local.conceallevel = 2
		vim.opt_local.concealcursor = "nc"
	end,
	desc = "Enable org-mode link concealment",
})

-- ============================================================================
-- ORG MODE - AUTO-CREATE FILES FROM LINKS
-- ============================================================================

vim.api.nvim_create_autocmd("FileType", {
	pattern = "org",
	callback = function()
		-- Open/create files from org links (directories created on save via global autocmd)
		vim.keymap.set("n", "<leader>oo", function()
			local line = vim.api.nvim_get_current_line()
			local filepath = line:match("%[%[file:([^%]]+)%]")

			if filepath then
				-- Remove search/anchor parts (e.g., ::*Heading or ::#custom-id)
				filepath = filepath:match("^([^:]+)") or filepath
				filepath = vim.trim(filepath)

				-- Get current file's directory for relative paths
				local current_file_dir = vim.fn.expand("%:p:h")
				local full_path

				-- Handle different path formats
				if filepath:match("^~") then
					-- Home directory path
					full_path = vim.fn.expand(filepath)
				elseif filepath:match("^/") or filepath:match("^%a:") then
					-- Absolute path (Unix or Windows)
					full_path = filepath
				else
					-- Relative path - relative to current file
					full_path = current_file_dir .. "/" .. filepath
				end

				-- Normalize path
				full_path = vim.fn.fnamemodify(full_path, ":p")

				-- Check if file exists
				local file_exists = vim.fn.filereadable(full_path) == 1

				-- Open/create the file (directories will be created on save)
				vim.cmd("edit " .. vim.fn.fnameescape(full_path))

				if not file_exists then
					vim.notify("Created new file: " .. full_path, vim.log.levels.INFO)
				end
			else
				-- No file link found, use orgmode's default link handler
				-- This handles web links, internal links, etc.
				require("orgmode").action("org_mappings.open_at_point")
			end
		end, { buffer = true, desc = "Open/create link at point" })
	end,
	desc = "Setup auto-create links for org files",
})

-- ============================================================================
-- ORG MODE - INSERT FILE LINK HELPER
-- ============================================================================

vim.api.nvim_create_autocmd("FileType", {
	pattern = "org",
	callback = function()
		-- Insert a file link with description
		vim.keymap.set("n", "<leader>oif", function()
			-- Get relative path input
			local filepath = vim.fn.input("File path (relative to current file): ")
			if filepath == "" then
				return
			end

			-- Get description
			local description = vim.fn.input("Link description: ")

			-- Format the link
			local link
			if description ~= "" then
				link = string.format("[[file:%s][%s]]", filepath, description)
			else
				link = string.format("[[file:%s]]", filepath)
			end

			-- Insert at cursor position
			local row, col = unpack(vim.api.nvim_win_get_cursor(0))
			local line = vim.api.nvim_get_current_line()
			local new_line = line:sub(1, col) .. link .. line:sub(col + 1)
			vim.api.nvim_set_current_line(new_line)

			-- Move cursor after the link
			vim.api.nvim_win_set_cursor(0, { row, col + #link })
		end, { buffer = true, desc = "Insert file link" })
	end,
})

-- ============================================================================
-- ORG MODE - NEW FILE TEMPLATE
-- ============================================================================

-- Function to insert org file template
local function insert_org_template(filepath)
	local filename = vim.fn.fnamemodify(filepath, ":t:r")
	local date = os.date("%Y-%m-%d")
	local author = vim.fn.system("git config user.name"):gsub("\n", "")

	if author == "" then
		author = vim.fn.expand("$USER")
	end

	local template = {
		"#+TITLE: " .. filename:gsub("_", " "):gsub("-", " "),
		"#+DATE: " .. date,
		"#+AUTHOR: " .. author,
		"",
		"* ",
	}

	vim.api.nvim_buf_set_lines(0, 0, -1, false, template)
	-- Move cursor to after the first heading
	vim.api.nvim_win_set_cursor(0, { 5, 2 })
end

vim.api.nvim_create_autocmd("BufNewFile", {
	pattern = "*.org",
	callback = function()
		insert_org_template(vim.fn.expand("%:p"))
	end,
	desc = "Insert template in new org files",
})
