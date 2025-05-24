
#!/bin/bash

SESSION_NAME="default"

# Check if there are any tmux sessions
if tmux has-session 2>/dev/null; then
    tmux attach-session
else
    tmux new-session -s "$SESSION_NAME"
fi
