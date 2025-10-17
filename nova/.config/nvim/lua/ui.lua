-- ============================================================================
-- FOLD PERSISTENCE
-- ============================================================================
-- Automatically save and restore fold state
vim.api.nvim_create_autocmd("BufWinLeave", {
	pattern = "*",
	callback = function()
		if vim.bo.filetype ~= "" and vim.bo.buftype == "" then
			vim.cmd("silent! mkview")
		end
	end,
	desc = "Save fold state when leaving buffer",
})
vim.api.nvim_create_autocmd("BufWinEnter", {
	pattern = "*",
	callback = function()
		if vim.bo.filetype ~= "" and vim.bo.buftype == "" then
			vim.cmd("silent! loadview")
		end
	end,
	desc = "Restore fold state when entering buffer",
})
