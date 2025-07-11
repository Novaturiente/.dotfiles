#! /usr/bin/zsh

question=$(rofi -show -dmenu -theme spotlight -p "Question")
exit_code=$?

if [ $exit_code -eq 0 ]; then
  foot --title "aiassistant" --working-directory "$HOME/develop/agent" zsh -c "source $HOME/.zshrc && uv run agent.py '$question'" 
else
  echo "$exit_code"
fi
