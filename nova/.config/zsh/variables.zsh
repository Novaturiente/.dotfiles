# ---- Editor Configuration ----
export VISUAL="nvim"
export EDITOR="nvim"
export NVIM_LOG_FILE="$HOME/.cache/nvim/my_custom_log.txt"  # Custom Neovim log file

# ---- Man Page Formatting ----
export MANROFFOPT="-c"
export MANPAGER="sh -c 'col -bx | bat -l man -p'"

# ---- Custom PATH Configuration ----


gobin="${GOPATH:-$HOME/go}/bin"
if [ -d "$gobin" ] && [[ ":$PATH:" != *":$gobin:"* ]]; then
  export PATH="$gobin:$PATH"
fi

# ---- Locale Settings ----
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
