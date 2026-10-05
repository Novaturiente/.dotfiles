# Quiet pi startup: ponytail's "Ponytail loaded" notice and pi-claude-code-provider's
# "linux/x64 is a compatibility candidate" warning (Arch here, not their WSL2 baseline).
# BORROW_SOLE_DIRECTORY: lets pi-observational-memory's tool-bearing worker calls (no cwd in prompt) run on the session model.
# Also follows the session into its final directory (e.g. a worktree) on exit, like Claude Code.
function pi --wraps pi --description 'pi with quiet startup notices; cd to final session dir on exit'
    set -l cwd_file (mktemp)
    PONYTAIL_QUIET_STARTUP=1 PI_CLAUDE_CODE_PROVIDER_ACKNOWLEDGED_PLATFORM=linux/x64 PI_CLAUDE_CODE_PROVIDER_BORROW_SOLE_DIRECTORY=on PI_CWD_FILE=$cwd_file command pi $argv
    set -l st $status
    set -l dir (cat $cwd_file 2>/dev/null)
    rm -f $cwd_file
    if test -n "$dir" -a -d "$dir" -a "$dir" != "$PWD"
        cd $dir
    end
    return $st
end
