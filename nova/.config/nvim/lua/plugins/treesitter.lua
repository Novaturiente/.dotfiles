-- ============================================================================
-- TREESITTER: syntax highlighting + indentation (nvim-treesitter `main` branch)
-- master branch caps at nvim 0.11; this machine runs 0.12+ -> main branch.
-- ============================================================================
local ensure_installed = {
	"bash",
	"lua",
	"luadoc",
	"python",
	"rust",
	"go",
	"gomod",
	"json",
	"yaml",
	"toml",
	"markdown",
	"markdown_inline",
	"vim",
	"vimdoc",
	"diff",
}

return {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	lazy = false,
	build = ":TSUpdate",
	config = function()
		local ts = require("nvim-treesitter")
		ts.setup()

		-- Install only missing parsers (install() is idempotent but this avoids
		-- re-downloading on every startup).
		local installed = {}
		for _, lang in ipairs(ts.get_installed("parsers")) do
			installed[lang] = true
		end
		local missing = {}
		for _, lang in ipairs(ensure_installed) do
			if not installed[lang] then
				table.insert(missing, lang)
			end
		end
		if #missing > 0 then
			ts.install(missing)
		end

		-- Enable highlight + indent for any buffer whose filetype has a parser.
		vim.api.nvim_create_autocmd("FileType", {
			group = vim.api.nvim_create_augroup("nvim_treesitter_start", { clear = true }),
			callback = function(args)
				local lang = vim.treesitter.language.get_lang(args.match)
				if not lang then
					return
				end
				if pcall(vim.treesitter.start, args.buf, lang) then
					vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
				end
			end,
		})
	end,
}
