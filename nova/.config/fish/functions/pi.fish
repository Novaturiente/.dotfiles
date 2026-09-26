# Quiet pi startup: ponytail's "Ponytail loaded" notice and pi-claude-code-provider's
# "linux/x64 is a compatibility candidate" warning (Arch here, not their WSL2 baseline).
function pi --wraps pi --description 'pi with quiet startup notices'
    PONYTAIL_QUIET_STARTUP=1 PI_CLAUDE_CODE_PROVIDER_ACKNOWLEDGED_PLATFORM=linux/x64 command pi $argv
end
