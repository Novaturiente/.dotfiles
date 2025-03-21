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

    set dir (sudo find ~/ -type d | sed "s|^$HOME|~|" | fzf --header=(basename (status current-command)) \
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

    if test -n "$dir"
	echo "test dir $dir"

	set expanded_dir (string replace -r '^~' $HOME "$dir")
	
        if test "$expanded_dir" != "$dir"
	    echo "found ~"
	    set dir $expanded_dir
	    echo "mod dir $dir"
	else
	    echo "not found ~"
	end

        cd "$dir"
    else
        echo "No directory selected."
    end
end


function edit
    sudo true

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

    
    if test -n "$file"
        set abs_path (realpath (dirname "$file"))
        cd "$abs_path"
        fish -c "nvim $file"
        
        # Path to the file that logs recently opened files
        set recent_file ~/.config/fish/.recently_opened_files
    
        # Check if the recent file log exists
        if test -f $recent_file
            # Read all lines into a variable
            set recent_files (cat $recent_file)
    
            # Remove the file from the list if it's already in the file
            set recent_files (string match -v -r "^$file\$" $recent_files)
    
            # Write each line back to the file, one by one
            echo -n "" > $recent_file  # Clear the file first
            for line in $recent_files
                echo $line >> $recent_file
            end
        else
            # Create the file if it doesn't exist
            touch $recent_file
        end
    
        # Append the newly opened file as the last line in the file
        echo $file >> $recent_file
    end
end


function edit-
    sudo true

    set recent_file ~/.config/fish/.recently_opened_files

    if test -f $recent_file
        set file (tac $recent_file | fzf --header="Recently Opened Files" \
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

    if test -n "$file"
        set abs_path (realpath (dirname "$file"))
        cd "$abs_path"
        fish -c "nvim $file"
        
        set recent_file ~/.config/fish/.recently_opened_files
        if test -f $recent_file
            set recent_files (cat $recent_file)
            set recent_files (string match -v -r "^$file\$" $recent_files)
            echo -n "" > $recent_file  # Clear the file first
            for line in $recent_files
                echo $line >> $recent_file
            end
        else
            touch $recent_file
        end
        echo $file >> $recent_file
    else
        echo "No file selected."
    end
end
