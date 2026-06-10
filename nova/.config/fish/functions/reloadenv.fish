# Re-source ~/.env into the current shell without restarting fish.
# Use after editing ~/.env so already-open sessions pick up new vars.
function reloadenv
    if test -f $HOME/.env
        fenv source $HOME/.env
        echo "reloaded ~/.env"
    else
        echo "~/.env not found" >&2
        return 1
    end
end
