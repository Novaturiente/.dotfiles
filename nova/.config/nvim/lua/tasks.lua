-- Task scratchpad. Only active when explicitly required:
--   nvim -c "lua require('tasks').open()"
-- Never loaded by normal nvim startup.
--
-- tasks.md format:
--   # Category        <- headings are left alone
--   - [ ] a task      <- bare lines become checkboxes
-- Completing a task moves it to completed.md under the same heading.

local M = {}

local dir = vim.fn.expand("~/notes")
local files = {
  tasks = dir .. "/tasks.md",
  completed = dir .. "/completed.md",
  notes = dir .. "/notes.md",
}

local busy = false

local function is_heading(l) return l:match("^%s*#") ~= nil end

local function save(buf)
  if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].modified then
    vim.api.nvim_buf_call(buf, function() vim.cmd("silent write") end)
  end
end

local function buf(name) return vim.fn.bufnr(files[name]) end

-- Append `items` to the section owned by `heading` (nil = the pre-heading
-- preamble). Creates the heading at EOF when it does not exist yet.
local function insert_under(b, heading, items)
  local lines = vim.api.nvim_buf_get_lines(b, 0, -1, false)
  -- A buffer always has >=1 line, so an empty file reads as one blank line.
  local blank = #lines == 1 and lines[1] == ""
  if blank then lines = {} end

  local start
  if heading then
    for i, l in ipairs(lines) do
      if l == heading then start = i break end
    end
    if not start then
      local tail = {}
      if #lines > 0 and lines[#lines] ~= "" then tail[#tail + 1] = "" end
      tail[#tail + 1] = heading
      vim.list_extend(tail, items)
      vim.api.nvim_buf_set_lines(b, blank and 0 or -1, -1, false, tail)
      return
    end
  else
    if blank then
      vim.api.nvim_buf_set_lines(b, 0, -1, false, items)
      return
    end
    start = 0
  end

  -- End of this section: the next heading, or EOF.
  local stop = #lines
  for i = start + 1, #lines do
    if is_heading(lines[i]) then stop = i - 1 break end
  end
  -- Don't leave the new items after the section's trailing blank lines.
  while stop > start and lines[stop] == "" do stop = stop - 1 end

  vim.api.nvim_buf_set_lines(b, stop, stop, false, items)
end

-- Group items by heading, preserving the order headings were encountered.
local function grouped()
  local order, byheading = {}, {}
  return {
    add = function(heading, item)
      local key = heading or "\0"
      if not byheading[key] then
        byheading[key] = { heading = heading, items = {} }
        order[#order + 1] = key
      end
      table.insert(byheading[key].items, item)
    end,
    each = function(fn)
      for _, key in ipairs(order) do fn(byheading[key].heading, byheading[key].items) end
    end,
    empty = function() return #order == 0 end,
  }
end

-- Normalise bare lines into checkboxes; migrate checked ones to completed.
local function sync()
  if busy then return end
  busy = true

  local tb, cb = buf("tasks"), buf("completed")
  local keep, changed = {}, false
  local done = grouped()
  local heading = nil

  for _, line in ipairs(vim.api.nvim_buf_get_lines(tb, 0, -1, false)) do
    if is_heading(line) then
      heading = line
      keep[#keep + 1] = line
    elseif line:match("^%s*$") then
      keep[#keep + 1] = line
    elseif line:match("^%- %[[xX]%] ") then
      done.add(heading, (line:gsub("^%- %[[xX]%] ", "- [x] ")))
      changed = true
    elseif line:match("^%- %[ %] ") then
      keep[#keep + 1] = line
    else
      keep[#keep + 1] = "- [ ] " .. line:gsub("^%s*[-*]%s*", "")
      changed = true
    end
  end

  if changed then
    local win = vim.api.nvim_get_current_win()
    local cur = vim.api.nvim_win_get_buf(win) == tb and vim.api.nvim_win_get_cursor(win) or nil
    vim.api.nvim_buf_set_lines(tb, 0, -1, false, keep)
    if cur then
      -- The "- [ ] " prefix shifts the column by 6.
      local row = math.min(cur[1], math.max(#keep, 1))
      vim.api.nvim_win_set_cursor(win, { row, math.min(cur[2] + 6, #(keep[row] or "")) })
    end
  end

  if not done.empty() then
    done.each(function(h, items) insert_under(cb, h, items) end)
    save(cb)
  end
  save(tb)
  busy = false
end

-- The heading governing buffer line `row` (1-indexed), or nil.
local function heading_at(b, row)
  local lines = vim.api.nvim_buf_get_lines(b, 0, row, false)
  for i = #lines, 1, -1 do
    if is_heading(lines[i]) then return lines[i] end
  end
  return nil
end

local function complete_lines(first, last)
  local lines = vim.api.nvim_buf_get_lines(0, first - 1, last, false)
  for i, l in ipairs(lines) do
    lines[i] = l:gsub("^(%- %[) %]", "%1x]")
  end
  vim.api.nvim_buf_set_lines(0, first - 1, last, false, lines)
  sync()
end

local function uncomplete_lines(first, last)
  busy = true
  local cb, tb = buf("completed"), buf("tasks")
  local lines = vim.api.nvim_buf_get_lines(cb, first - 1, last, false)

  local back, keep = grouped(), {}
  for i, l in ipairs(lines) do
    if l:match("^%- %[[xX]%] ") then
      back.add(heading_at(cb, first + i - 1), (l:gsub("^%- %[[xX]%]", "- [ ]")))
    else
      keep[#keep + 1] = l -- headings and blanks in the selection stay put
    end
  end

  if not back.empty() then
    vim.api.nvim_buf_set_lines(cb, first - 1, last, false, keep)
    back.each(function(h, items) insert_under(tb, h, items) end)
    save(cb)
    save(tb)
  end
  busy = false
end

function M.open()
  vim.fn.mkdir(dir, "p")
  for _, f in pairs(files) do
    if vim.fn.filereadable(f) == 0 then vim.fn.writefile({}, f) end
  end

  -- Bufferline orders by buffer number, so open in display order.
  vim.cmd.edit(files.tasks)
  vim.cmd.edit(files.completed)
  vim.cmd.edit(files.notes)
  vim.cmd.buffer(files.tasks)

  local tb, cb = buf("tasks"), buf("completed")

  vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave" }, { buffer = tb, callback = sync })
  vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave", "FocusLost" }, {
    callback = function(a) save(a.buf) end,
  })

  local function map(b, lhs, rhs, desc)
    vim.keymap.set({ "n", "x" }, lhs, rhs, { buffer = b, desc = desc })
  end

  local function range_action(fn)
    return function()
      local mode = vim.fn.mode()
      if mode == "v" or mode == "V" then
        vim.cmd('normal! \27') -- leave visual so '< '> are set
        fn(vim.fn.line("'<"), vim.fn.line("'>"))
      else
        local l = vim.fn.line(".")
        fn(l, l)
      end
    end
  end

  map(tb, "<leader>x", range_action(complete_lines), "Complete task")
  map(tb, "<CR>", range_action(complete_lines), "Complete task")
  map(cb, "<leader>x", range_action(uncomplete_lines), "Reopen task")
  map(cb, "<CR>", range_action(uncomplete_lines), "Reopen task")

  for _, b in pairs({ tb, cb, buf("notes") }) do
    vim.keymap.set("n", "<Tab>", "<cmd>bnext<CR>", { buffer = b, desc = "Next tab" })
    vim.keymap.set("n", "<S-Tab>", "<cmd>bprevious<CR>", { buffer = b, desc = "Previous tab" })
  end

  -- Land at the bottom of the task list, in normal mode.
  vim.schedule(function()
    local win = vim.api.nvim_get_current_win()
    if vim.api.nvim_win_get_buf(win) == tb then
      vim.api.nvim_win_set_cursor(win, { vim.api.nvim_buf_line_count(tb), 0 })
    end
  end)
end

return M
