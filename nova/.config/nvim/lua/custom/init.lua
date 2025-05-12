local M = {}

function M.copy_visual_to_clipboard()
  local bufnr = vim.api.nvim_get_current_buf()
  local start_pos = vim.api.nvim_buf_get_mark(bufnr, "<")
  local end_pos = vim.api.nvim_buf_get_mark(bufnr, ">")
  local start_line = start_pos[1]
  local end_line = end_pos[1]
  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end
  local old_reg = vim.fn.getreg('"')
  local old_regtype = vim.fn.getregtype('"')
  vim.cmd('normal! ""y')
  local selected_text = vim.fn.getreg('"')
  vim.ui.input({ prompt = 'Enter additional text (optional): ' }, function(input)
    input = input or ""
    local combined_text = input .. "\n" .. selected_text
    vim.fn.setreg('+', combined_text)
    local plugin_path = debug.getinfo(1, "S").source:sub(2)
    local plugin_dir = vim.fn.fnamemodify(plugin_path, ":h")
    local ai_binary = plugin_dir .. "/ai"
    if vim.fn.filereadable(ai_binary) ~= 1 then
      vim.notify("Error: 'ai' binary not found at: " .. ai_binary, vim.log.levels.ERROR)
      return
    end
    local temp_file = vim.fn.tempname()
    local file = io.open(temp_file, "w")
    if file then
      file:write(combined_text)
      file:close()
    else
      vim.notify("Failed to create temporary file", vim.log.levels.ERROR)
      return
    end
    vim.notify("Processing request with AI...", vim.log.levels.INFO)
    vim.fn.jobstart(vim.fn.shellescape(ai_binary) .. ' "$(cat ' .. vim.fn.shellescape(temp_file) .. ')"', {
      on_stdout = function(_, data)
        os.remove(temp_file)
        if not data or #data <= 1 then
          vim.notify("Empty response received", vim.log.levels.WARN)
          return
        end
        local response_text = table.concat(data, "\n")
        response_text = response_text:gsub("%s+$", "")
        vim.fn.setreg('+', response_text)
        vim.notify("Response copied to clipboard", vim.log.levels.INFO)
        local response_lines = {}
        for _, line in ipairs(data) do
          if line and line ~= "" then
            table.insert(response_lines, line)
          end
        end
        local float_buf = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(float_buf, 0, -1, false, response_lines)
        vim.api.nvim_buf_set_option(float_buf, 'filetype', 'markdown')
        vim.api.nvim_buf_set_option(float_buf, 'syntax', 'on')
        local width = math.floor(vim.o.columns * 0.7)
        local height = math.min(#response_lines + 2, math.floor(vim.o.lines * 0.7))
        local row = math.floor((vim.o.lines - height) / 2 - 1)
        local col = math.floor((vim.o.columns - width) / 2)
        local win = vim.api.nvim_open_win(float_buf, true, {
          relative = 'editor',
          width = width,
          height = height,
          row = row,
          col = col,
          style = 'minimal',
          border = 'rounded',
          title = "AI Response (Copied to Clipboard)",
          title_pos = "center"
        })
        vim.api.nvim_buf_set_keymap(float_buf, 'n', '<Esc>', ':q<CR>', { noremap = true, silent = true })
        vim.api.nvim_buf_set_keymap(float_buf, 'n', 'y', 
          ':let @+ = join(getline(1, "$"), "\\n")<CR>:echo "Response copied to clipboard again"<CR>', 
          { noremap = true, silent = true })
        vim.api.nvim_buf_set_keymap(float_buf, 'n', 'q', ':q<CR>', { noremap = true, silent = true })
      end,
      on_stderr = function(_, data)
        os.remove(temp_file)
        if data and #data > 1 then
          local error_msg = table.concat(data, "\n")
          vim.notify("Error executing 'ai' binary: " .. error_msg, vim.log.levels.ERROR)
        end
      end,
      stdout_buffered = true,
      stderr_buffered = true,
    })
    vim.fn.setreg('"', old_reg, old_regtype)
  end)
end
function M.get_plugin_dir()
  local plugin_path = debug.getinfo(1, "S").source:sub(2)
  return vim.fn.fnamemodify(plugin_path, ":h")
end
return M
