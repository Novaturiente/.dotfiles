# CLAUDE.md - Dotfiles Repository Guide

## Repository Overview

Personal dotfiles and system configuration for an Arch Linux (CachyOS kernel) setup on a **Lenovo IdeaPad Slim 5** with **Intel Core Ultra 5 (Meteor Lake)** integrated graphics. Managed via GNU Stow for symlink-based deployment and a custom Rust binary (`novarch`) for declarative package management.

**Remote:** `git@github.com:Novaturiente/.dotfiles.git`

## Repository Structure

```
.dotfiles/
├── nova/                  # Home directory configs (deployed via `stow -t ~ nova`)
│   ├── .config/           # XDG_CONFIG_HOME contents (~70 app configs)
│   ├── .fonts/            # Custom fonts (SF Pro Display, Steelfish)
│   ├── .gitconfig         # Git identity: Novaturiente <Novaturiente@proton.me>
│   ├── .password-store/   # GPG-encrypted passwords (pass)
│   ├── .profile           # Base env vars, XDG dirs, API keys
│   ├── .zprofile          # Login shell overrides
│   ├── .zshrc             # Main shell config (vi mode, zoxide, fzf, atuin)
│   └── .tmux.conf         # Tmux config (backtick prefix, vi mode, sesh)
├── scripts/               # Custom utility scripts
│   ├── rofi/              # Rofi launcher scripts (bookmarks, clipboard, power, tmux, tools)
│   └── keybindings/       # Auto-extract keybindings from niri/nvim/qutebrowser/tmux
├── system/
│   ├── novarch            # Compiled Rust binary - declarative package manager
│   ├── novarch.back       # Backup of previous novarch version
│   ├── package/           # YAML package lists (one file per category)
│   ├── system/            # System config files (mirrors /etc structure)
│   │   ├── boot/          # GRUB theme (CyberSynchro)
│   │   └── etc/           # TLP, Ly, systemd services, GRUB defaults
│   └── setup.sh           # First-boot system setup script
└── .gitignore
```

## Key Tools & Conventions

### Package Management (`system/package/`)
- **Format:** Simple YAML lists — each file is an array of package names (`- package-name`)
- **Commented packages** (`#- package-name`) are disabled/not installed
- **Categories:** base-system, terminal-tools, windowmanager, development, work, internet, media, gaming (disabled), nvidia (disabled), virtualization (empty)
- **novarch** reads these YAML files and syncs installed packages declaratively
- **paru** is the AUR helper

### Dotfile Deployment
- Uses **GNU Stow**: `stow -d ~/.dotfiles -t ~ nova` creates symlinks from `nova/` into `$HOME`
- File paths under `nova/` mirror the home directory structure exactly
- Example: `nova/.config/ghostty/config` → `~/.config/ghostty/config`

### System Config Deployment
- Files under `system/system/` mirror the `/` filesystem structure
- Deployed manually via `cp` commands in `setup.sh`
- Example: `system/system/etc/tlp.conf` → `/etc/tlp.conf`

## Desktop Environment Stack

| Layer | Tool | Config Location |
|-------|------|-----------------|
| Window Manager | **Niri** (Wayland tiling compositor) | `nova/.config/niri/config.kdl` |
| Alt WM | Hyprland (also configured) | `nova/.config/hypr/` |
| Login Manager | **Ly** (TUI) | `system/system/etc/ly/config.ini` |
| Panel | **Waybar** + DankMaterialShell | `nova/.config/waybar/`, `nova/.config/DankMaterialShell/` |
| Notifications | **swaync** | `nova/.config/swaync/` |
| Launcher | **Rofi** (Wayland fork) | `nova/.config/rofi/` |
| Wallpaper | **wpaperd** (random, 15min cycle) | `nova/.config/wpaperd/` |
| Idle/Lock | **swayidle** | `nova/.config/swayidle/` |
| Screenshots | grim + slurp + satty | bound in niri config |
| Screen Record | wl-screenrec | `scripts/record-script.sh` |
| Clipboard | wl-clipboard + cliphist | autostarted in WM config |

## Shell & Terminal

| Tool | Details |
|------|---------|
| **Shell** | fish (primary, default login shell), zsh (also configured) |
| **Terminal** | Ghostty (IosevkaTerm Nerd Font, size 13, Catppuccin Mocha, 50% opacity) |
| **Multiplexer** | tmux (prefix: backtick `` ` ``, vi mode, sesh session manager) |
| **History** | atuin (synced) |
| **Navigation** | zoxide (cd replacement), fzf (fuzzy finder) |
| **ls replacement** | eza (with icons and color) |
| **cat replacement** | bat (plain mode default) |
| **find replacement** | fd |
| **grep replacement** | ripgrep (rg) |

### Shell Config Loading Order
1. `.profile` — XDG dirs, API keys, base env
2. `.zprofile` — login overrides (editor=neovide, Rust mirrors)
3. `.zshrc` — sources `.profile`, then loads from `$XDG_CONFIG_HOME/zsh/`:
   - `variables.zsh` — editor, PATH, locale
   - `aliases.zsh` — 80+ aliases (eza, trash, git, podman, ssh)
   - `pluginload.zsh` — zsh plugins (autopair, syntax-highlighting, autosuggestions, autocomplete)
   - `prompt.zsh` — powerline-style prompt with git/language detection
4. **fish** (default login shell) — `~/.config/fish/config.fish` re-declares the same env/PATH, then auto-loads `conf.d/*.fish` (aliases, autopair, auto-venv). Completions: carapace bridge + native fish + man-page-generated (`fish_update_completions`). Plugins via fisher (`fish_plugins`). Inline autosuggestions read `~/.local/share/fish/fish_history` (not atuin's DB).

### Notable Aliases
- `rm` → `trash-put` (safe delete)
- `cp` → `rsync` (progress bar)
- `ls/la/ll/lt` → `eza` variants
- `gadd` → auto-stage and commit with message
- `macup/macdown` → podman compose for WinApps
- `ollamaup/ollamadown` → podman compose for Ollama

## Editors

### Neovim (primary)
- Config: `nova/.config/nvim/` (Lua-based)
- Plugin manager: lazy.nvim
- Leader key: Space
- Font: JetBrainsMonoNL Nerd Font, size 13
- Tabs: 4 spaces
- Modules: `plugins.lua`, `keybindinds.lua`, `ui.lua`, `coding.lua`, `autostart.lua`, `orgsetup.lua`
- GUI: Neovide (90% opacity, blur, cursor trail)

### Doom Emacs (secondary)
- Config: `nova/.config/doom/`
- Theme: doom-challenger-deep
- Font: JetBrains Mono NL Nerd Font, size 15
- Evil mode (vim keybindings)
- Used for org-mode and as PDF viewer

## Scripts (`scripts/`)

### System Control
| Script | Purpose |
|--------|---------|
| `brightness.sh` | Adaptive step brightness (1% below 32%, 5% above) |
| `volume.sh` | playerctl volume adjust |
| `mute.sh` | pamixer mute toggle |
| `idle.sh` | Toggle swayidle daemon |
| `battery-limit.sh` | Lenovo IdeaPad battery conservation mode (70%+ → enable) |
| `dns.sh` | Toggle Adguard DNS on NetworkManager connection |
| `wallpaper.sh` | Random wallpaper loop (30min, swaybg) |

### Productivity
| Script | Purpose |
|--------|---------|
| `fix_grammar.sh` | Clipboard text → NVIDIA API (gpt-oss-120b) → grammar correction → paste back |
| `ocr_select.sh` | Region select → screenshot → Tesseract OCR → clipboard |
| `file_picker.sh` | Zenity file dialog → wl-copy → ydotool paste |
| `calendar-notify.sh` | Parse khal events → schedule 10min-before notifications via `at` |
| `record-script.sh` | wl-screenrec wrapper (full/region/audio modes) |
| `llm.sh` | Toggle Ollama server |

### Rofi Menus (`scripts/rofi/`)
| Script | Purpose |
|--------|---------|
| `bookmarks.sh` | Browser bookmark manager with title fetching |
| `clipboard.sh` | Clipboard history with image preview |
| `find.sh` | File finder → open in neovide |
| `power.sh` | Logout/shutdown/reboot with confirmation |
| `tmux.sh` | Tmux session switcher/creator |
| `tools.sh` | File operations (copy, move, rename, delete, restore) |

### Keybinding Extractors (`scripts/keybindings/`)
Auto-extract and display keybindings from niri, neovim, qutebrowser, and tmux configs into a unified rofi menu.

## System Configuration

### Power Management (TLP)
- AC: performance governor, performance EPP
- Battery: powersave governor, balance_power EPP
- Battery charge thresholds: start 75%, stop 80%
- WiFi power saving: off on AC, on on battery
- Sleep mode: s2idle (modern standby)

### Firewall (iptables)
- INPUT: DROP by default
- Allow: established connections, loopback, KDE Connect (1714-1764), SSH (22)
- OUTPUT: ACCEPT all

### Boot
- GRUB with CyberSynchro theme, 3s timeout
- Kernel params: `loglevel=3 quiet splash i915.enable_psr=1`

### Systemd Services
- `battery-limit.timer` — runs battery limit script every 5 min
- `batsignal.service` — battery notifications (critical: 10%, warning: 30%, full: 95%)
- `tmux-default.service` — persistent default tmux session

## Theming & Fonts

- **GTK/Qt:** Materia theme, WhiteSur icons, Bibata cursor
- **Terminal font:** IosevkaTerm Nerd Font (size 13)
- **Editor font:** JetBrains Mono NL Nerd Font (size 13-15)
- **Color schemes:** Catppuccin Mocha (Ghostty), CachyOS colors (Hyprland), Challenger Deep (Emacs)
- **Icon theme:** Cool-Dark-Icons (Rofi), WhiteSur (GTK)

## Browsers
- **Primary:** Zen Browser (Wayland)
- **Secondary:** Qutebrowser (keyboard-driven, dark mode, Catppuccin theme)
- **Work:** Google Chrome, Thorium (separate qutebrowser profile at `nova/.config/qutebrowser_work/`)

## Development Languages & Tools
- **Rust** (rustup, rust-analyzer, Tsinghua mirrors)
- **Python** (uv package manager, pyright, ruff)
- **Node.js** (LTS, npm-global)
- **Go**
- **Lua** (luarocks)
- **Java** (OpenJDK, for work)
- **Databases:** PostgreSQL (+ pgvector), MySQL, DBeaver GUI
- **Containers:** Docker + Podman (WinApps Windows VM via podman-compose)
- **Git tools:** lazygit, git-filter-repo

## File Management
- **Terminal:** Yazi (primary), Ranger (secondary)
- **Yazi keybindings:** Mount menu (M), SMB shares (gs), create (mk), drag-drop (Ctrl+Y)
- **MIME defaults:** zen (web), emacs (PDF), imv (images), mpv (video/audio), ranger (dirs)

## Hardware Specifications

| Component | Details |
|-----------|---------|
| **Laptop** | Lenovo IdeaPad Slim 5 14IMH9 (Board: LNVNB161216) |
| **BIOS** | N7CN34WW (2025-09-24) |
| **CPU** | Intel Core Ultra 5 125H (Meteor Lake) — 14 cores / 18 threads, up to 4.5 GHz |
| | 6 P-cores (hyperthreaded) + 8 E-cores, 18 MB L3 cache, VT-x virtualization |
| **GPU** | Intel Arc Graphics (Meteor Lake-P, i915 driver) — 256 MB dedicated + shared VRAM |
| | VAAPI hardware decode, vulkan-intel — no discrete GPU |
| **NPU** | Intel Meteor Lake NPU (neural/AI accelerator) |
| **RAM** | 16 GB (15.2 GiB usable), soldered |
| **Storage** | Samsung PM9C1a 1 TB NVMe SSD (DRAM-less, PCIe) |
| | 2 GB EFI partition (`/boot`, vfat) + 952 GB btrfs (root + home, single partition) |
| **Swap** | 15.2 GB zram (compressed) + ~24 GB swap file |
| **WiFi** | Intel AX211 (WiFi 6E, CNVi, Meteor Lake PCH) |
| **Bluetooth** | Intel AX211 BT 5.3 |
| **Webcam** | Bison Integrated RGB Camera (USB) |
| **Card Reader** | O2 Micro SD/MMC Controller |
| **Ports** | Thunderbolt 4 (USB-C), USB 3.2 Gen 2x1 |
| **Display** | 14" 1920x1080 @ 60 Hz (eDP-1), intel_backlight |
| **Kernel** | linux-cachyos 6.19.x (PREEMPT_DYNAMIC, clang/LLD built) |
| **Filesystem** | Btrfs (single partition for / and /home) |
| **Networking** | Tailscale VPN active, Docker/Podman bridge networks |

### Hardware-Specific Config Notes
- **TLP** is tuned for Meteor Lake: s2idle sleep, Intel HWP, NatACPI battery thresholds (75-80%)
- **Battery conservation** managed via Lenovo IdeaPad ACPI sysfs (`/sys/bus/platform/drivers/ideapad_acpi/`)
- **i915 PSR** (Panel Self Refresh) enabled in kernel params for display power saving
- **intel-compute-runtime** + **intel-media-driver** installed for OpenCL and media acceleration
- **intel-npu-driver-bin** installed for NPU support
- **No NVIDIA packages** — nvidia.yaml and gaming.yaml are fully commented out

## Important Notes

- **Wayland-native:** All scripts assume Wayland (wl-copy, slurp, grim, ydotool, wlopm)
- **Nerd Fonts required:** Icons used throughout rofi, prompts, waybar, and terminal configs
- **Sensitive files:** API keys and credentials are stored in `.profile` and `.env` files — never commit actual values
