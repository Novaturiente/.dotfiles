-- plugin/copy_and_chat.lua

local function copy_file_and_chat(opts)
  -- Get the current buffer number
  local bufnr = vim.api.nvim_get_current_buf()

  -- Get all the lines in the buffer (entire file content)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local file_content = table.concat(lines, "\n") -- Concatenate lines into a single string

  if not file_content or file_content == "" then
    vim.notify("The file is empty.", vim.log.levels.ERROR)
    return
  end

  local script_path = opts.script_path or "/home/nova/distrobox/tool/temp.py"

  -- Escape the file content for safe argument passing
  local escaped_content = vim.fn.shellescape(file_content)

  -- Construct the command
  local command = string.format("python %s %s", script_path, escaped_content)

  -- Execute the command and capture the output
  local result = vim.fn.system(command)

  -- Open a vertical split to display the output
  vim.cmd("vsplit") -- Create a vertical split
  vim.cmd("enew") -- Open a new empty buffer
  local result_bufnr = vim.api.nvim_get_current_buf()

  -- Write the chatbot's response to the new buffer
  vim.api.nvim_buf_set_lines(result_bufnr, 0, -1, false, vim.split(result, "\n"))
  vim.api.nvim_buf_set_option(result_bufnr, "modifiable", false) -- Make the buffer read-only

  vim.notify("Chatbot response displayed.", vim.log.levels.INFO)
end

-- Register the user command
vim.api.nvim_create_user_command(
  "CopyAndChat",
  function(opts)
    copy_file_and_chat(opts)
  end,
  {
    desc = "Send file content to the chatbot script and display the response.",
    nargs = "?",
    complete = "file",
  }
)
