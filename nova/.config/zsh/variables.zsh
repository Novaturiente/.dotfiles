# ---- Editor Configuration ----
export VISUAL="nvim"
export EDITOR="nvim"
export NVIM_LOG_FILE="$HOME/.cache/nvim/my_custom_log.txt"  # Custom Neovim log file

# ---- Man Page Formatting ----
export MANROFFOPT="-c"
export MANPAGER="sh -c 'col -bx | bat -l man -p'"

export PATH=/usr/bin:$PATH
# ---- Custom PATH Configuration ----
# Add ~/.local/bin to PATH if not already present
if [ -d "$HOME/.local/bin" ] && [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  export PATH="$HOME/.local/bin:$PATH"
fi


if [ -d "$HOME/go/bin" ] && [[ ":$PATH:" != *":$HOME/go/bin:"* ]]; then
  export PATH="$HOME/go/bin:$PATH"
fi
# Add depot_tools to PATH if not already present
if [ -d "$HOME/Applications/depot_tools" ] && [[ ":$PATH:" != *":$HOME/Applications/depot_tools:"* ]]; then
  export PATH="$HOME/Applications/depot_tools:$PATH"
fi

# ---- Nix Environment ----
# Ensure nix environment is sourced in Zsh
export NIX_PROFILES="$HOME/.nix-profile"
if [ -n "$ZSH_VERSION" ]; then
    if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
        source "$HOME/.nix-profile/etc/profile.d/nix.sh"
    fi
fi
