# Prepend/strip `sudo ` on the command line; if empty, reuse last command.
# Bound to Esc Esc in fish_user_key_bindings (replaces zsh-sudo plugin).
function __sudo_toggle
    set -l cmd (commandline)
    test -z "$cmd"; and set cmd $history[1]
    if string match -q 'sudo *' -- $cmd
        commandline -r (string sub -s 6 -- $cmd)
    else
        commandline -r "sudo $cmd"
    end
    commandline -f end-of-line
end
