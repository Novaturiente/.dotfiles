return {
  "coder/claudecode.nvim",
  dependencies = { "folke/snacks.nvim" },
  cmd = {
    "ClaudeCode", "ClaudeCodeFocus", "ClaudeCodeSend",
    "ClaudeCodeAdd", "ClaudeCodeDiffAccept", "ClaudeCodeDiffDeny",
  },
  keys = {
    { "<leader>ac", "<cmd>ClaudeCode<cr>",      desc = "Toggle Claude" },
    { "<leader>af", "<cmd>ClaudeCodeFocus<cr>", desc = "Focus Claude" },
    { "<leader>as", "<cmd>ClaudeCodeSend<cr>",  mode = "v", desc = "Send selection to Claude" },
  },
  opts = {
    terminal = {
      split_side = "right",
      split_width_percentage = 0.40, -- 40% right pane
    },
  },
  config = function(_, opts)
    require("claudecode").setup(opts)

    -- Root nvim cwd to the file's project so Claude launches in project dir,
    -- not wherever nvim was started (e.g. home via file picker).
    local root_markers = { ".git", "Cargo.toml", "package.json", "pyproject.toml", "go.mod", "lua" }
    vim.api.nvim_create_autocmd({ "BufEnter", "BufReadPost" }, {
      callback = function(args)
        local name = vim.api.nvim_buf_get_name(args.buf)
        if name == "" or vim.bo[args.buf].buftype ~= "" then return end
        local root = vim.fs.root(args.buf, root_markers)
        if root and root ~= vim.fn.getcwd() then
          vim.fn.chdir(root)
        end
      end,
    })

    -- Auto-accept diffs instantly = no review popup, edits land live in buffer
    vim.api.nvim_create_autocmd("User", {
      pattern = "ClaudeCodeDiffOpened",
      callback = function() vim.cmd("ClaudeCodeDiffAccept") end,
    })

    -- Backstop: reload buffers changed on disk (files not open / external writes)
    vim.o.autoread = true
    vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
      command = "checktime",
    })
  end,
}
