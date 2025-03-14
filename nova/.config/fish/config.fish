set fish_greeting

source ~/.config/fish/cachyos-config.fish

zoxide init fish | source

alias vi="nvim"

set VISUAL "nvim"
set EDITOR "nvim"

alias winstart="docker compose --file ~/.config/winapps/compose.yaml start"
alias winstop="docker compose --file ~/.config/winapps/compose.yaml stop"
alias winrestart="docker compose --file ~/.config/winapps/compose.yaml restart"
# overwrite greeting
# potentially disabling fastfetch
#function fish_greeting
#    # smth smth
#end

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
#eval /home/nova/.conda/bin/conda "shell.fish" "hook" $argv | source
# <<< conda initialize <<<

function move
  # List directories recursively, including hidden directories
  set dir (sudo find . -type d | fzf --header=(basename (status current-command)) \
           --layout=reverse \
           --exact \
           --border=bold \
           --border=rounded \
           --margin=5% \
           --multi \
           --color=dark \
           --height=95% \
           --info=hidden \
           --header-first \
           --bind change:top \
           --prompt='> ')
  
  # Check if a directory was selected
  if test -n "$dir"
    # Get the absolute path of the selected directory
    set abs_path (realpath "$dir")
    cd "$abs_path"
    echo "Selected directory: $abs_path"
  else
    echo "No directory selected."
  end
end


function edit
  sudo true

  # List files recursively, including hidden files
  set file (sudo find . -type f | fzf --header=(basename (status current-command)) \
             --layout=reverse \
             --exact \
             --border=bold \
             --border=rounded \
             --margin=5% \
             --multi \
             --color=dark \
             --height=95% \
             --info=hidden \
             --header-first \
             --bind change:top \
             --prompt='> ')

  # Check if a file was selected
  if test -n "$file"
    sudo nvim "$file"
  else
    echo "No file selected."
  end
end

