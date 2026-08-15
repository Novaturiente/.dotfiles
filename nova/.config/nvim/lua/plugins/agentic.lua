-- ============================================================================
-- AGENTIC: in-editor AI chat over ACP (Agent Client Protocol)
-- ============================================================================
-- Needs the provider CLI on PATH: npm i -g @agentclientprotocol/claude-agent-acp
-- Auth comes from the claude CLI login; no API key here.
return {
	"carlos-algms/agentic.nvim",
	--- @type agentic.PartialUserConfig
	opts = {
		provider = "claude-agent-acp",
	},
	keys = {
		{ "<leader>ac", function() require("agentic").toggle() end, mode = { "n", "v" }, desc = "Toggle Agentic chat" },
		{ "<leader>aa", function() require("agentic").add_selection_or_file_to_context() end, mode = { "n", "v" }, desc = "Add file/selection to context" },
		{ "<leader>an", function() require("agentic").new_session() end, mode = { "n", "v" }, desc = "New Agentic session" },
		{ "<leader>ar", function() require("agentic").restore_session() end, mode = { "n", "v" }, desc = "Restore Agentic session" },
		{ "<leader>ad", function() require("agentic").add_current_line_diagnostics() end, desc = "Add line diagnostic to Agentic" },
		{ "<leader>aD", function() require("agentic").add_buffer_diagnostics() end, desc = "Add buffer diagnostics to Agentic" },
	},
}
