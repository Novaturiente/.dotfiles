local dap = require('dap')
local dapui = require('dapui')
local dap_python = require('dap-python')

-- Setup Python debugger with uv
local function setup_python_debugger()
  -- Try to find debugpy in the uv environment
  local uv_python = vim.fn.system("uv run python -c 'import sys; print(sys.executable)'"):gsub("\n", "")
  
  if vim.v.shell_error == 0 and uv_python ~= "" then
    -- Use uv's Python interpreter
    dap_python.setup(uv_python)
  else
    -- Fallback to system Python
    dap_python.setup('python')
  end
  
  -- Configure Python adapter to use uv run
  dap.adapters.python = {
    type = 'executable',
    command = 'uv',
    args = { 'run', 'python', '-m', 'debugpy.adapter' },
    options = {
      source_filetype = 'python',
    }
  }
  
  -- Configure Python configurations
  dap.configurations.python = {
    {
      type = 'python',
      request = 'launch',
      name = "Launch file with uv",
      program = "${file}",
      pythonPath = function()
        local uv_python_path = vim.fn.system("uv run python -c 'import sys; print(sys.executable)'"):gsub("\n", "")
        if vim.v.shell_error == 0 and uv_python_path ~= "" then
          return uv_python_path
        else
          return '/usr/bin/python'
        end
      end,
      console = 'integratedTerminal',
      justMyCode = true,
    },
    {
      type = 'python',
      request = 'launch',
      name = "Debug with arguments",
      program = "${file}",
      args = function()
        local args_string = vim.fn.input('Arguments: ')
        return vim.split(args_string, " ")
      end,
      pythonPath = function()
        local uv_python_path = vim.fn.system("uv run python -c 'import sys; print(sys.executable)'"):gsub("\n", "")
        if vim.v.shell_error == 0 and uv_python_path ~= "" then
          return uv_python_path
        else
          return '/usr/bin/python'
        end
      end,
      console = 'integratedTerminal',
      justMyCode = true,
    },
    {
      type = 'python',
      request = 'attach',
      name = 'Attach remote',
      connect = function()
        local host = vim.fn.input('Host [127.0.0.1]: ')
        host = host ~= '' and host or '127.0.0.1'
        local port = tonumber(vim.fn.input('Port [5678]: ')) or 5678
        return { host = host, port = port }
      end,
    },
  }
end
-- Call the setup function
setup_python_debugger()

-- Function to check if current directory is a uv project
local function is_uv_project()
  local pyproject_path = vim.fn.getcwd() .. "/pyproject.toml"
  local uv_lock_path = vim.fn.getcwd() .. "/uv.lock"
  return vim.fn.filereadable(pyproject_path) == 1 or vim.fn.filereadable(uv_lock_path) == 1
end

-- Smart debug function that automatically chooses between uv and regular Python
function SmartDebugPython()
  local file = vim.fn.expand('%')
  if vim.fn.expand('%:e') ~= 'py' then
    print("Not a Python file")
    return
  end
  
  if is_uv_project() then
    -- We're in a uv project, use uv debugging
    print("🐍 Debugging with UV...")
    local uv_check = vim.fn.system("uv run python --version 2>/dev/null")
    if vim.v.shell_error == 0 then
      dap.run(dap.configurations.python[1]) -- Launch file with uv
    else
      print("❌ UV not available, falling back to regular Python debugging")
      dap_python.test_method()
    end
  else
    -- Regular Python project, use standard debugging
    print("🐍 Debugging with regular Python...")
    dap_python.test_method()
  end
end

-- Keep the specific functions for manual override
function DebugPythonUV()
  local file = vim.fn.expand('%')
  if vim.fn.expand('%:e') == 'py' then
    local uv_check = vim.fn.system("uv run python --version 2>/dev/null")
    if vim.v.shell_error == 0 then
      dap.run(dap.configurations.python[1])
    else
      print("❌ UV not available in this project")
    end
  else
    print("Not a Python file")
  end
end

function DebugPython()
  local file = vim.fn.expand('%')
  if vim.fn.expand('%:e') == 'py' then
    dap_python.test_method()
  else
    print("Not a Python file")
  end
end
