# Fish completions for Claude Code (`claude`).
# Hand-authored from `claude --help` (v2.1.x). carapace has no claude completer,
# so this drives the native fish completion pager. Update when claude adds flags.

# Don't suggest subcommands after the first non-option token (interactive prompt).
function __claude_no_subcommand -d 'no claude subcommand seen yet'
    set -l cmd (commandline -opc)
    set -e cmd[1]
    for t in $cmd
        switch $t
            case agents auth auto-mode doctor install mcp plugin plugins project setup-token ultrareview update upgrade
                return 1
        end
    end
    return 0
end

# ---- Subcommands ----
complete -c claude -f -n __claude_no_subcommand -a agents      -d 'Manage background agents'
complete -c claude -f -n __claude_no_subcommand -a auth        -d 'Manage authentication'
complete -c claude -f -n __claude_no_subcommand -a auto-mode   -d 'Inspect auto mode classifier configuration'
complete -c claude -f -n __claude_no_subcommand -a doctor      -d 'Check the health of your Claude Code auto-updater'
complete -c claude -f -n __claude_no_subcommand -a install     -d 'Install Claude Code native build'
complete -c claude -f -n __claude_no_subcommand -a mcp         -d 'Configure and manage MCP servers'
complete -c claude -f -n __claude_no_subcommand -a plugin      -d 'Manage Claude Code plugins'
complete -c claude -f -n __claude_no_subcommand -a plugins     -d 'Manage Claude Code plugins'
complete -c claude -f -n __claude_no_subcommand -a project     -d 'Manage Claude Code project state'
complete -c claude -f -n __claude_no_subcommand -a setup-token -d 'Set up a long-lived authentication token'
complete -c claude -f -n __claude_no_subcommand -a ultrareview -d 'Cloud-hosted multi-agent code review'
complete -c claude -f -n __claude_no_subcommand -a update      -d 'Check for updates and install if available'
complete -c claude -f -n __claude_no_subcommand -a upgrade     -d 'Check for updates and install if available'

# ---- install subcommand args ----
complete -c claude -f -n '__fish_seen_subcommand_from install' -a 'stable latest' -d 'Version target'

# ---- Options with choice arguments ----
complete -c claude -x -l model          -a 'fable opus sonnet claude-fable-5 claude-opus-4-8 claude-sonnet-4-6 claude-haiku-4-5-20251001' -d 'Model for the session'
complete -c claude -x -l fallback-model -a 'fable opus sonnet claude-fable-5 claude-opus-4-8 claude-sonnet-4-6 claude-haiku-4-5-20251001' -d 'Fallback model(s)'
complete -c claude -x -l effort          -a 'low medium high xhigh max'                              -d 'Effort level'
complete -c claude -x -l permission-mode -a 'acceptEdits auto bypassPermissions default dontAsk plan' -d 'Permission mode'
complete -c claude -x -l output-format   -a 'text json stream-json'                                  -d 'Output format (with --print)'
complete -c claude -x -l input-format    -a 'text stream-json'                                       -d 'Input format (with --print)'

# ---- Flags (no argument) ----
complete -c claude -f -s c -l continue                          -d 'Continue most recent conversation here'
complete -c claude -f -s p -l print                             -d 'Print response and exit (pipes)'
complete -c claude -f -s h -l help                              -d 'Display help'
complete -c claude -f -s v -l version                           -d 'Output the version number'
complete -c claude -f      -l bare                              -d 'Minimal mode (skip hooks, LSP, plugins...)'
complete -c claude -f      -l safe-mode                         -d 'Start with all customizations disabled'
complete -c claude -f      -l chrome                            -d 'Enable Claude in Chrome integration'
complete -c claude -f      -l no-chrome                         -d 'Disable Claude in Chrome integration'
complete -c claude -f      -l ide                               -d 'Auto-connect to IDE on startup'
complete -c claude -f      -l dangerously-skip-permissions      -d 'Bypass all permission checks'
complete -c claude -f      -l allow-dangerously-skip-permissions -d 'Allow bypassing permission checks as an option'
complete -c claude -f      -l fork-session                      -d 'Resume into a new session ID'
complete -c claude -f      -l disable-slash-commands            -d 'Disable all skills'
complete -c claude -f      -l verbose                           -d 'Override verbose mode setting'
complete -c claude -f      -l strict-mcp-config                 -d 'Only use MCP servers from --mcp-config'
complete -c claude -f      -l brief                             -d 'Enable SendUserMessage tool'
complete -c claude -f      -l tmux                              -d 'Create tmux session for worktree'
complete -c claude -f      -l include-hook-events               -d 'Include hook lifecycle events in output'
complete -c claude -f      -l include-partial-messages          -d 'Include partial message chunks'
complete -c claude -f      -l no-session-persistence            -d 'Disable session persistence'
complete -c claude -f      -l replay-user-messages              -d 'Re-emit user messages on stdout'
complete -c claude -f      -l exclude-dynamic-system-prompt-sections -d 'Move per-machine sections to first user message'

# ---- Options taking a value ----
complete -c claude -r -l add-dir            -d 'Additional dirs for tool access' -a '(__fish_complete_directories)'
complete -c claude -x -l agent              -d 'Agent for the current session'
complete -c claude -x -l agents             -d 'JSON object defining custom agents'
complete -c claude -x -l allowed-tools      -d 'Tool names to allow'
complete -c claude -x -l disallowed-tools   -d 'Tool names to deny'
complete -c claude -x -l tools              -d 'Available tools from built-in set'
complete -c claude -x -l system-prompt      -d 'System prompt for the session'
complete -c claude -x -l append-system-prompt -d 'Append to default system prompt'
complete -c claude -x -s d -l debug         -d 'Enable debug mode (optional filter)'
complete -c claude -r -l debug-file         -d 'Write debug logs to a file'
complete -c claude -x -l betas              -d 'Beta headers for API requests'
complete -c claude -x -s n -l name          -d 'Display name for this session'
complete -c claude -x -s r -l resume        -d 'Resume a conversation by session ID'
complete -c claude -x -l from-pr            -d 'Resume a session linked to a PR'
complete -c claude -x -l session-id         -d 'Use a specific session ID (UUID)'
complete -c claude -r -l settings           -d 'Settings JSON file or string'
complete -c claude -x -l setting-sources    -d 'Setting sources (user, project, local)'
complete -c claude -x -l mcp-config         -d 'Load MCP servers from JSON files/strings'
complete -c claude -x -l json-schema        -d 'JSON Schema for structured output'
complete -c claude -x -l max-budget-usd     -d 'Max dollar amount to spend (with --print)'
complete -c claude -r -l plugin-dir         -d 'Load a plugin from a dir or .zip' -a '(__fish_complete_directories)'
complete -c claude -x -l plugin-url         -d 'Fetch a plugin .zip from a URL'
complete -c claude -x -l file               -d 'File resources to download at startup'
complete -c claude -x -l remote-control     -d 'Interactive session with Remote Control'
complete -c claude -x -l prompt-suggestions -a 'true false' -d 'Enable prompt suggestions'
complete -c claude -x -s w -l worktree      -d 'Create a git worktree for this session'
