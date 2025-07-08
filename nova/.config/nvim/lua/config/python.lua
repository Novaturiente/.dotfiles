-- ========================================================
-- 🐍 PYTHON CONFIGURATION
-- ========================================================

local lspconfig = require("lspconfig")
local capabilities = require("cmp_nvim_lsp").default_capabilities()
local dap = require('dap')
local dapui = require('dapui')
local dap_python = require('dap-python')
local wk = require("which-key")

-- Common on_attach function for all LSP servers
local function on_attach(client, bufnr)
  -- Set up buffer-local keymaps with which-key descriptions
  client.server_capabilities.offsetEncoding = "utf-8"
  
  -- This single block now handles both creating the keymap AND registering it with which-key
  require("which-key").add({
    mode = "n", -- Set the mode for all keys in this table
    { "gd", vim.lsp.buf.definition, desc = "Go to definition" },
    { "gD", vim.lsp.buf.declaration, desc = "Go to declaration" },
    { "gi", vim.lsp.buf.implementation, desc = "Go to implementation" },
    { "gr", vim.lsp.buf.references, desc = "Go to references" },
    { "gt", vim.lsp.buf.type_definition, desc = "Go to type definition" },
    { "K",  vim.lsp.buf.hover, desc = "Hover documentation" },
    { "<C-k>", vim.lsp.buf.signature_help, desc = "Signature help" },
    { "<leader>ca", vim.lsp.buf.code_action, desc = "Code action" },
    { "<leader>rn", vim.lsp.buf.rename, desc = "Rename symbol" },
    { "<leader>f", function() vim.lsp.buf.format({ async = true }) end, desc = "Format buffer" },
    
    -- You can also add your diagnostic keybindings here for consistency
    { "[d", vim.diagnostic.goto_prev, desc = "Previous diagnostic" },
    { "]d", vim.diagnostic.goto_next, desc = "Next diagnostic" },
    { "<leader>e", vim.diagnostic.open_float, desc = "Line diagnostics" },
    { "<leader>ql", vim.diagnostic.setloclist, desc = "List diagnostics" },

  }, { buffer = bufnr })

  -- If you have mappings for other modes (e.g., visual mode), you can add another block
  require("which-key").add({
    mode = "v",
    { "<leader>ca", vim.lsp.buf.code_action, desc = "Code action" },
  }, { buffer = bufnr })
end

-- PYTHON LSP CONFIG (Kept)
lspconfig.pyright.setup({
  capabilities = capabilities,
  on_attach = on_attach,
  settings = {
    pyright = {
      disableOrganizeImports = true,
    },
    python = {
      analysis = {
        ignore = { '*' },
        typeCheckingMode = "basic",
        autoSearchPaths = true,
        useLibraryCodeForTypes = true,
      },
    },
  },
})

lspconfig.ruff.setup({
  capabilities = capabilities,
  on_attach = on_attach,
  init_options = {
    settings = {
      args = {},
    }
  }
})

-- Setup DAP UI
dapui.setup({
  icons = { expanded = "", collapsed = "", current_frame = "" },
  mappings = {
    expand = { "<CR>", "<2-LeftMouse>" },
    open = "o",
    remove = "d",
    edit = "e",
    repl = "r",
    toggle = "t",
  },
  expand_lines = vim.fn.has("nvim-0.7") == 1,
  layouts = {
    {
      elements = {
        { id = "scopes", size = 0.25 },
        "breakpoints",
        "stacks",
        "watches",
      },
      size = 40,
      position = "left",
    },
    {
      elements = {
        "repl",
        "console",
      },
      size = 0.25,
      position = "bottom",
    },
  },
  controls = {
    enabled = true,
    element = "repl",
    icons = {
      pause = "",
      play = "",
      step_into = "",
      step_over = "",
      step_out = "",
      step_back = "",
      run_last = "",
      terminate = "",
    },
  },
  floating = {
    max_height = nil,
    max_width = nil,
    border = "single",
    mappings = {
      close = { "q", "<Esc>" },
    },
  },
})

-- Setup virtual text
require("nvim-dap-virtual-text").setup()

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

-- Configure breakpoint signs
vim.fn.sign_define('DapBreakpoint', {text='🔴', texthl='', linehl='', numhl=''})
vim.fn.sign_define('DapBreakpointCondition', {text='🟡', texthl='', linehl='', numhl=''})
vim.fn.sign_define('DapLogPoint', {text='🔵', texthl='', linehl='', numhl=''})
vim.fn.sign_define('DapStopped', {text='➡️', texthl='', linehl='', numhl=''})
vim.fn.sign_define('DapBreakpointRejected', {text='❌', texthl='', linehl='', numhl=''})

-- Auto open/close DAP UI
dap.listeners.after.event_initialized["dapui_config"] = function()
  dapui.open()
end
dap.listeners.before.event_terminated["dapui_config"] = function()
  dapui.close()
end
dap.listeners.before.event_exited["dapui_config"] = function()
  dapui.close()
end

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

-- Debug keybindings
wk.add{
  { "<leader>d", group = "Debug" },
  -- MAIN DEBUG FUNCTIONS
  { "<leader>dd", SmartDebugPython, desc = "🧠 Smart Debug (Auto UV/Python)" },
  { "<leader>dv", DebugPythonUV, desc = "🚀 Force UV Debug" },
  { "<leader>dp", DebugPython, desc = "🐍 Force Regular Python Debug" },
  { "<leader>da", "<cmd>lua require('dap').run(require('dap').configurations.python[2])<CR>", desc = "Debug with Args" },

  { "<leader>ds", "<cmd>lua require('dap').continue()<CR>", desc = "Start/Continue" },
  { "<leader>db", "<cmd>lua require('dap').toggle_breakpoint()<CR>", desc = "Toggle Breakpoint" },
  { "<leader>dB", "<cmd>lua require('dap').set_breakpoint(vim.fn.input('Breakpoint condition: '))<CR>", desc = "Conditional Breakpoint" },
  { "<leader>dc", "<cmd>lua require('dap').run_last()<CR>", desc = "Run Last" },
  { "<leader>du", "<cmd>lua require('dapui').toggle()<CR>", desc = "Toggle UI" },
  { "<leader>do", "<cmd>lua require('dap').step_over()<CR>", desc = "Step Over" },
  { "<leader>di", "<cmd>lua require('dap').step_into()<CR>", desc = "Step Into" },
  { "<leader>dO", "<cmd>lua require('dap').step_out()<CR>", desc = "Step Out" },
  { "<leader>dr", "<cmd>lua require('dap').repl.open()<CR>", desc = "Open REPL" },
  { "<leader>dt", "<cmd>lua require('dap').terminate()<CR>", desc = "Terminate" },
  { "<leader>dh", "<cmd>lua require('dap.ui.widgets').hover()<CR>", desc = "Hover Variables" },
  { "<leader>dp", "<cmd>lua require('dap.ui.widgets').preview()<CR>", desc = "Preview" },
  { "<leader>df", "<cmd>lua local widgets=require('dap.ui.widgets');widgets.centered_float(widgets.frames)<CR>", desc = "Frames" },
  { "<leader>dS", "<cmd>lua local widgets=require('dap.ui.widgets');widgets.centered_float(widgets.scopes)<CR>", desc = "Scopes" },
  { "<leader>dC", "<cmd>lua require('dap').clear_breakpoints()<CR>", desc = "Clear All Breakpoints" },
  { "<leader>dR", "<cmd>lua require('dap').run_to_cursor()<CR>", desc = "Run to Cursor" },
  -- Removed duplicate <leader>dd mapping here, as SmartDebugPython is preferred
}
