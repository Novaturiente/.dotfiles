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
│   └── .tmux.conf         # Tmux config (backtick prefix, vi mode)
├── scripts/               # Custom utility scripts
│   ├── rofi/              # Rofi menus (calendar, password, window switcher, tv-edit)
│   ├── quickshell/        # Quickshell menu launchers/controllers (bound in niri)
│   └── keybindings/       # Auto-extract keybindings from niri/nvim/qutebrowser
├── system/
│   ├── novarch            # Compiled Rust binary - declarative package manager
│   ├── novarch.back       # Backup of previous novarch version
│   ├── package/           # YAML package lists (one file per category)
│   ├── system/            # System config files (mirrors /etc structure)
│   │   ├── etc/           # TLP, Ly, PAM, systemd services, udev, sudoers
│   │   └── usr/           # /usr/local helpers (vpn-run, mullvad-netns, howdy-ir-pre)
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
| Login Manager | **Ly** (TUI greeter on tty2, `ly@tty2.service`) | `system/system/etc/ly/config.ini` |
| Panel / Notifications / Wallpaper | **DankMaterialShell** (`dms`, Quickshell-based) | `nova/.config/DankMaterialShell/`, `nova/.config/niri/dms/` |
| Launcher / menus | **Quickshell** daemons (`qs -c <name> -d`), Rofi for a few helpers | `nova/.config/quickshell/`, `nova/.config/rofi/` |
| Idle/Lock | **swayidle** → `dms ipc call lock lock` | `nova/.config/swayidle/config` |
| Screenshots | grim + slurp + satty | bound in niri config |
| Screen Record | wf-recorder (region/audio), wl-screenrec (fullscreen) | `scripts/record-script.sh` |
| Clipboard | wl-clipboard + cliphist | autostarted in WM config |

## Shell & Terminal

| Tool | Details |
|------|---------|
| **Shell** | fish (primary, default login shell), zsh (also configured) |
| **Terminal** | Ghostty (IosevkaTerm Nerd Font, size 13, Catppuccin Mocha, 50% opacity) |
| **Multiplexer** | tmux (prefix: backtick `` ` ``, vi mode) |
| **History** | atuin (synced) |
| **Navigation** | zoxide (cd replacement), fzf (fuzzy finder) |
| **ls replacement** | eza (with icons and color) |
| **cat replacement** | bat (plain mode default) |
| **find replacement** | fd |
| **grep replacement** | ripgrep (rg) |

### Shell Config Loading Order
1. `.profile` — XDG dirs, API keys, base env
2. `.zprofile` — login overrides (Rust mirrors)
3. `.zshrc` — sources `.profile`, then loads from `$XDG_CONFIG_HOME/zsh/`:
   - `variables.zsh` — editor, PATH, locale
   - `aliases.zsh` — aliases and helper functions (eza, trash, git, ssh, `cproj`)
   - `pluginload.zsh` — zsh plugins (autopair, syntax-highlighting, autosuggestions, autocomplete)
   - `prompt.zsh` — powerline-style prompt with git/language detection
4. **fish** (default login shell) — `~/.config/fish/config.fish` re-declares the same env/PATH, then auto-loads `conf.d/*.fish` (aliases, autopair, auto-venv). Completions: carapace bridge + native fish + man-page-generated (`fish_update_completions`). Plugins via fisher (`fish_plugins`). Inline autosuggestions read `~/.local/share/fish/fish_history` (not atuin's DB).

### Notable Aliases
- `rm` → `trash-put` (safe delete)
- `cp` → `rsync` (progress bar)
- `ls/la/ll/lt` → `eza` variants
- `gadd` → auto-stage and commit with message
- `winstart/winstop/winrestart/winsopen` → drive the Windows VM on `novahome` over ssh + docker

## Editors

### Neovim (only editor)
- Config: `nova/.config/nvim/` (Lua-based)
- Plugin manager: lazy.nvim
- Leader key: Space
- Font: JetBrainsMonoNL Nerd Font, size 13
- Tabs: 4 spaces
- Modules: `plugins.lua`, `keybindinds.lua`, `ui.lua`, `coding.lua`, `autostart.lua`, `orgsetup.lua`

## Scripts (`scripts/`)

### System Control
| Script | Purpose |
|--------|---------|
| `brightness.sh` | Adaptive step brightness (1% below 32%, 5% above) |
| `volume.sh` | playerctl volume adjust |
| `battery-limit.sh` | Lenovo IdeaPad battery conservation mode (70%+ → enable) |
| `dns.sh` | Toggle Adguard DNS on NetworkManager connection |
| `tv-only-output.sh` | Switch niri output to the TV only |

### Productivity
| Script | Purpose |
|--------|---------|
| `fix_grammar.sh` | Clipboard text → NVIDIA API (gpt-oss-120b) → grammar correction → paste back |
| `ocr_select.sh` | Region select → screenshot → Tesseract OCR → clipboard |
| `file_picker.sh` | Zenity file dialog → wl-copy → ydotool paste |
| `calendar-notify.sh` | Parse khal events → schedule 10min-before notifications via `at` |
| `record-script.sh` | wl-screenrec wrapper (full/region/audio modes) |

### Rofi Menus (`scripts/rofi/`)
| Script | Purpose |
|--------|---------|
| `calendar.sh` | khal calendar front-end |
| `passrofi.sh` | rbw password picker with per-domain autofill |
| `windows.sh` | Window switcher for niri |
| `tv-edit.sh` | Edit the TV output configuration |

### Keybinding Extractors (`scripts/keybindings/`)
Auto-extract and display keybindings from niri, neovim, and qutebrowser configs into a unified rofi menu.

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
- systemd-boot (managed by `systemd-boot-manager`); no GRUB on this system
- Kernel params: `loglevel=3 quiet splash i915.enable_psr=1`

### Systemd Services
- `battery-limit.timer` — runs battery limit script every 5 min
- `batsignal.service` — battery notifications (critical: 10%, warning: 30%, full: 95%)

## Theming & Fonts

- **GTK/Qt:** Materia theme, WhiteSur icons, Bibata cursor
- **Terminal font:** IosevkaTerm Nerd Font (size 13)
- **Editor font:** JetBrains Mono NL Nerd Font (size 13-15)
- **Color schemes:** Catppuccin Mocha (Ghostty), DankMaterialShell-generated palettes (niri, nvim, ghostty)
- **Icon theme:** Cool-Dark-Icons (Rofi), WhiteSur (GTK)

## Browsers
- **Primary:** Zen Browser (Wayland)
- **Secondary:** Qutebrowser (keyboard-driven, dark mode, Catppuccin theme)
- **Work:** Google Chrome, Brave

## Development Languages & Tools
- **Rust** (rustup, rust-analyzer, Tsinghua mirrors)
- **Python** (uv package manager, pyright, ruff)
- **Node.js** (LTS, npm-global)
- **Go**
- **Lua** (luarocks)
- **Java** (OpenJDK, for work)
- **Databases:** PostgreSQL (+ pgvector), MySQL, DBeaver GUI
- **Containers:** Docker (WinApps connects to a Windows VM on `novahome` in manual mode)
- **Git tools:** lazygit, git-filter-repo

## File Management
- No terminal file manager is installed; browse from the shell or `broot`.
- **MIME defaults** (`nova/.config/mimeapps.list`): zen (web), zathura (PDF/epub), imv (images), mpv (video/audio), nvim (everything text-shaped)

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

- **Wayland-native:** All scripts assume Wayland (wl-copy, slurp, grim, ydotool, niri msg)
- **Nerd Fonts required:** Icons used throughout rofi, quickshell, prompts, and terminal configs
- **Sensitive files:** API keys and credentials are stored in `.profile` and `.env` files — never commit actual values
