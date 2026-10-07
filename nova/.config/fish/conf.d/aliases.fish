# ===================================================================
# Aliases  (ported from ~/.config/zsh/aliases.zsh)
# Complex/multi-arg ones live as functions in functions/.
# ===================================================================

# ---- Editors / system ----
alias vi      'nvim'
alias cedit   "nvim -c 'enew | put + | setlocal buftype=nofile bufhidden=wipe noswapfile'"

# ---- novarch (declarative package manager) ----
alias inova   'sudo novarch install'
alias unova   'sudo novarch update'
alias anova   'sudo novarch add'
alias rnova   'sudo novarch remove'
alias editsystem 'nvim ~/.dotfiles/novarch'
alias systemupdate 'sudo reflector --latest 10 --protocol https --sort rate --save /etc/pacman.d/mirrorlist && paru -Syu'

# ---- ls (eza) ----
alias la 'eza -a  --color=always --group-directories-first --icons=always'
alias ls 'eza -al --color=always --group-directories-first --icons=always'
alias ll 'eza -l  --color=always --group-directories-first --icons=always'
alias lt 'eza -aT --color=always --group-directories-first --icons=always'
alias l. "eza -a | grep -e '^\.'"

# ---- safer / nicer coreutils ----
alias rm   'trash'
alias cp   'rsync -ah --info=progress2 --inplace --no-whole-file'
complete -c cp -e  # drop inherited rsync host/user completions; want plain file paths
alias cat  'bat --paging=never'
alias dir  'dir --color=auto'
alias vdir 'vdir --color=auto'
alias fgrep 'fgrep --color=auto'
alias egrep 'egrep --color=auto'
alias wget 'wget -c'
alias tarnow 'tar -acf'
alias untar  'tar -zxvf'

# ---- system control ----
alias jctl   'journalctl -p 3 -xb'
alias clear-cache 'rm -rf ~/.cache/qutebrowser && rm -rf ~/.cache/floorp'

# ---- git ----
alias gadd 'git add . && git commit -m "Update"'

# ---- misc ----
alias fileserver 'python3 -m http.server 8080 --directory ~/Share'
alias winstart 'ssh nova@novahome docker start windows'
alias winstop  'ssh nova@novahome docker stop windows'
alias winrestart 'ssh nova@novahome docker restart windows'
alias winsopen 'ssh nova@novahome docker start windows && winapps windows'

# ---- claude helpers ----
alias cld   'claude --dangerously-skip-permissions'
