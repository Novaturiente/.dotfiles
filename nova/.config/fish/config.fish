# ===================================================================
# FISH CONFIGURATION  (ported from zsh)
# ===================================================================

# -------------------------------------------------------------------
# Fisher bootstrap (declarative / reproducible)
#   Plugin list lives in ~/.config/fish/fish_plugins (committed).
#   First launch self-installs fisher + every listed plugin.
# -------------------------------------------------------------------
if status is-interactive
    if not functions -q fisher
        echo "fish: bootstrapping fisher + plugins..." >&2
        curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source
        fisher update
    end
end

# ===================================================================
# Environment Variables & PATH   (from .profile / .zprofile / variables.zsh)
# ===================================================================

# ---- XDG Base Directories ----
set -gx XDG_CONFIG_HOME $HOME/.config
set -gx XDG_DATA_HOME   $HOME/.local/share
set -gx XDG_CACHE_HOME  $HOME/.cache
set -gx XDG_STATE_HOME  $HOME/.local/state
set -gx XDG_DOTFILES_HOME $HOME/.dotfiles

# ---- Editor ----
# Catppuccin Mocha — built into fish >= 4.4, so no theme file needed.
# fish_config writes to fish_variables, which this repo gitignores as machine
# state, so choose it here to keep the theme reproducible.
fish_config theme choose catppuccin-mocha

set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx NVIM_LOG_FILE $HOME/.cache/nvim/my_custom_log.txt

# ---- Man page formatting (bat as pager) ----
set -gx MANROFFOPT -c
set -gx MANPAGER "sh -c 'col -bx | bat -l man -p'"

# ---- Locale ----
set -gx LANG en_US.UTF-8
set -gx LC_ALL en_US.UTF-8

# ---- Qt ----
set -gx QT_SELECT qt6

# ---- Mesa / GL vendor (Intel) ----
set -gx __EGL_VENDOR_LIBRARY_FILENAMES /usr/share/glvnd/egl_vendor.d/50_mesa.json
set -gx __GLX_VENDOR_LIBRARY_NAME mesa

# ---- Rustup mirrors (Tsinghua) ----
set -gx RUSTUP_DIST_SERVER https://mirrors.tuna.tsinghua.edu.cn/rustup
set -gx RUSTUP_UPDATE_ROOT https://mirrors.tuna.tsinghua.edu.cn/rustup/rustup

# ---- Per-app XDG overrides (relocate dirs out of $HOME) ----
set -gx CARGO_HOME $XDG_DATA_HOME/cargo
set -gx RUSTUP_HOME $XDG_DATA_HOME/rustup
set -gx GOPATH $XDG_DATA_HOME/go
set -gx BUN_INSTALL $XDG_DATA_HOME/bun
set -gx NPM_CONFIG_CACHE $XDG_CACHE_HOME/npm
set -gx ANDROID_HOME $HOME/Android/Sdk
set -gx ANDROID_USER_HOME $XDG_DATA_HOME/android
set -gx ANDROID_SDK_HOME $XDG_DATA_HOME/android
set -gx ADB_VENDOR_KEYS $XDG_DATA_HOME/android
set -gx _JAVA_OPTIONS "-Djava.util.prefs.userRoot=$XDG_CONFIG_HOME/java"
set -gx MAVEN_OPTS "-Dmaven.repo.local=$XDG_DATA_HOME/maven/repository"
set -gx RBENV_ROOT $XDG_DATA_HOME/rbenv
set -gx GNUPGHOME $XDG_DATA_HOME/gnupg
set -gx WGETRC $XDG_CONFIG_HOME/wget/wgetrc

# ---- PATH (fish_add_path dedupes + persists order) ----
fish_add_path -g $HOME/.local/bin
fish_add_path -g $CARGO_HOME/bin
fish_add_path -g $HOME/.npm-global/bin
test -d $GOPATH/bin;                     and fish_add_path -g $GOPATH/bin
test -d $HOME/Applications/depot_tools;  and fish_add_path -g $HOME/Applications/depot_tools
test -d $BUN_INSTALL/bin;                and fish_add_path -g $BUN_INSTALL/bin

# ===================================================================
# Secrets & POSIX-only env files (via fenv -> foreign-env plugin)
#   fenv runs the file in bash, captures the resulting env into fish.
# ===================================================================
if status is-interactive
    # ~/.env  (API keys, passwords) — the requested fenv bridge
    if test -f $HOME/.env
        if functions -q fenv
            fenv source $HOME/.env
        else
            # native fallback if fenv not yet installed
            for line in (string match -rv '^\s*(#|$)' < $HOME/.env)
                set -l clean (string replace -r '^\s*export\s+' '' -- $line)
                set -l kv (string split -m1 '=' -- $clean)
                test (count $kv) -eq 2; and set -gx $kv[1] (string trim -c '"\'' -- $kv[2])
            end
        end
    end

    # rustup/cargo env (ships a fish variant)
    if test -f $HOME/.local/bin/env.fish
        source $HOME/.local/bin/env.fish
    else if functions -q fenv; and test -f $HOME/.local/bin/env
        fenv source $HOME/.local/bin/env
    end

    # nix (guarded — not present yet, future-proof)
    if test -f $HOME/.nix-profile/etc/profile.d/nix.sh; and functions -q fenv
        fenv source $HOME/.nix-profile/etc/profile.d/nix.sh
    end

    # google-cloud-sdk (guarded)
    test -f $HOME/google-cloud-sdk/path.fish.inc; and source $HOME/google-cloud-sdk/path.fish.inc
end

# ===================================================================
# Interactive-only setup
# ===================================================================
if status is-interactive

    # ---- Shell behaviour ----
    set -g fish_greeting                       # no startup banner
    # autocd, case-insensitive completion, autosuggestions, syntax
    # highlighting: all built-in, no plugins or config needed.

    # ---- Colors (match zsh autosuggest, Catppuccin Mocha overlay0) ----
    set -g fish_color_autosuggestion 6c7086

    # venv handled by fish_right_prompt, not the activate script
    set -gx VIRTUAL_ENV_DISABLE_PROMPT 1

    # ---- Vi mode (replaces `bindkey -v`) ----
    set -g fish_key_bindings fish_vi_key_bindings
    set -g fish_cursor_default block
    set -g fish_cursor_insert  line
    set -g fish_cursor_visual  block
    # Allow multi-Esc chords (Esc Esc -> sudo). Without this fish treats the
    # first Esc as an immediate mode switch and `\e\e` never matches.
    set -g fish_sequence_key_delay_ms 200

    # ---- External tool init ----
    zoxide init fish --cmd cd | source         # cd replacement
    fzf --fish | source                        # fuzzy finder + Ctrl-T/Ctrl-R/Alt-C
    atuin init fish | source                   # magical history (Ctrl-R, Up)

    # ---- Carapace (multi-shell completion bridge) ----
    set -gx CARAPACE_BRIDGES 'zsh,fish,bash,inshellisense'
    carapace _carapace | source
end
