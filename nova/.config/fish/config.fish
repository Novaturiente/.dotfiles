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

  sudo true

  # List directories recursively, including hidden directories
  set dir (sudo find ~/ -type d | fzf --header=(basename (status current-command)) \
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

    # Path to the file that logs recently opened files
    set recent_file ~/.recently_opened_files

    # Check if the recent file exists and has content
    if test -f $recent_file
        # Show recently opened files first in fzf
        set file (cat $recent_file | fzf --header="Recently Opened Files" \
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
	     --preview='bat --style=numbers --color=always --line-range=:500 {} 2>/dev/null || cat {} 2>/dev/null' \
             --prompt='> ')

        # If no file was selected from the recent list, fallback to find command
        if test -z "$file"
            set file (sudo find ~/ -type f | fzf --header=(basename (status current-command)) \
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
		--preview='bat --style=numbers --color=always --line-range=:500 {} 2>/dev/null || cat {} 2>/dev/null' \
		--prompt='> ')
        end
    else
        # Fallback to find command if no recent file log exists
        set file (sudo find ~/ -type f | fzf --header=(basename (status current-command)) \
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
	     --preview='bat --style=numbers --color=always --line-range=:500 {} 2>/dev/null || cat {} 2>/dev/null' \
             --prompt='> ')
    end

    # Check if a file was selected
    if test -n "$file"
        set abs_path (realpath (dirname "$file"))
        cd "$abs_path"
        
        # Open the selected file with nvim
        fish -c "nvim $file"

        # Log the opened file to the recent file log
        echo $file >> $recent_file
    else
        echo "No file selected."
    end
end
