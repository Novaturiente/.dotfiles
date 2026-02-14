# Custom XDG Base Directories
export EDITOR="emacs --background-color=black"
export VISUAL="emacs --background-color=black"

export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_DOTFILES_HOME="$HOME/.dotfiles"

export QT_SELECT=qt6
export QT_QPA_PLATFORMTHEME=gtk3

[ -f ~/.env ] && set -a && source ~/.env && set +a

export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_DOTFILES_HOME="$HOME/.dotfiles"

export __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json
export __GLX_VENDOR_LIBRARY_NAME=mesa

. "$HOME/.local/share/../bin/env"

# export OPENROUTER_API_KEY="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"
# export ANTHROPIC_BASE_URL="https://openrouter.ai/api"
# export ANTHROPIC_AUTH_TOKEN="$OPENROUTER_API_KEY"

# export OPENAI_API_BASE="https://integrate.api.nvidia.com/v1"
# export OPENAI_API_KEY="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"
# export OPENAI_MODEL="z-ai/glm4.7"
export NVAPI_KEY="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"
