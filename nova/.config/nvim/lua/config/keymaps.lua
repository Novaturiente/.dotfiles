-- ============================================================================
-- KEYMAPS (non-plugin)
-- ============================================================================
-- leader is set in init.lua (space)
local map = vim.keymap.set

-- jk -> ESC
map("i", "jk", "<ESC>", { noremap = true, desc = "Exit insert mode" })

-- Clear search highlight
map("n", "<Esc>", "<cmd>nohlsearch<CR>", { silent = true, desc = "Clear search highlights" })

-- Save / quit
map("n", "<leader>w", "<cmd>w<CR>", { desc = "Save file" })
map("n", "<leader>q", "<cmd>bdelete<CR>", { desc = "Close buffer" })
map("n", "<leader>Q", "<cmd>qa<CR>", { desc = "Quit all" })

-- Buffer navigation (also via bufferline)
map("n", "<S-h>", "<cmd>bprevious<CR>", { desc = "Previous buffer" })
map("n", "<S-l>", "<cmd>bnext<CR>", { desc = "Next buffer" })

-- Messages: dump to a scratch buffer + copy to system clipboard
map("n", "<leader>m", function()
	local out = vim.fn.execute("messages")
	vim.fn.setreg("+", out) -- copy to system clipboard
	vim.cmd("botright new") -- scratch split
	vim.bo.buftype = "nofile"
	vim.bo.bufhidden = "wipe"
	vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(out, "\n"))
	vim.notify("Messages copied to clipboard")
end, { desc = "Messages -> buffer + clipboard" })

-- Window navigation
map("n", "<C-h>", "<C-w>h", { desc = "Window left" })
map("n", "<C-j>", "<C-w>j", { desc = "Window down" })
map("n", "<C-k>", "<C-w>k", { desc = "Window up" })
map("n", "<C-l>", "<C-w>l", { desc = "Window right" })
