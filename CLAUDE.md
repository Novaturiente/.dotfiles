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
- **Categories:** base-system, terminal-tools, windowmanager, development, work, internet, media, manual-install, nvidia (disabled), virtualization
- **novarch** reads these YAML files and syncs installed packages declaratively. `novarch install` **removes** any package it tracks (state in `/var/lib/novarch/state.yaml`) that no YAML declares, so declare a package before relying on it; `novarch diff` previews the sync
- **paru** is the AUR helper

### Dotfile Deployment
- Uses **GNU Stow**: `stow -d ~/.dotfiles -t ~ nova` creates symlinks from `nova/` into `$HOME`
- File paths under `nova/` mirror the home directory structure exactly
- Example: `nova/.config/ghostty/config` → `~/.config/ghostty/config`

### System Config Deployment
- Files under `system/system/` mirror the `/` filesystem structure
- Deployed as one tree by `setup.sh`: `sudo cp -r system/system/. /`
- Example: `system/system/etc/tlp.conf` → `/etc/tlp.conf`

## Desktop Environment Stack

| Layer | Tool | Config Location |
|-------|------|-----------------|
| Window Manager | **Niri** (Wayland tiling compositor) | `nova/.config/niri/config.kdl` |
| Login Manager | **Ly** (TUI greeter on tty2, `ly@tty2.service`) | `system/system/etc/ly/config.ini` |
| Panel / Wallpaper / Lock / OSD | **DankMaterialShell** (`dms`, Quickshell-based) | `nova/.config/DankMaterialShell/`, `nova/.config/niri/dms/` |
| Notifications | Own Quickshell daemon, ported from caelestia-shell. Runs as `quickshell-notifications.service`, **not** under niri startup. | `nova/.config/quickshell/notifications/` |
| Launcher / menus | **Quickshell** menus, started on demand by `scripts/quickshell/*.sh` and quit once closed and idle (nothing resident); Rofi for a few helpers | `nova/.config/quickshell/`, `nova/.config/rofi/` |
| Menu motion / widgets | `common/` QML module: Material 3 Expressive curves (`Tokens`, `Anim`), ripple (`StateLayer`), and the `Styled*` widget set. Ported by hand from [caelestia-shell](https://github.com/caelestia-dots/shell); no compiled plugin. | `nova/.config/quickshell/common/` |
| Idle/Lock | **swayidle**: lock with swaylock (`scripts/lock.sh`) at 5 min, screen off at 10 min, never suspends on idle | `nova/.config/swayidle/config` |
| Screenshots | grim + slurp + satty | bound in niri config |
| Screen Record | wf-recorder (region/audio), wl-screenrec (fullscreen) | `scripts/record-script.sh` |
| Clipboard | **cliphist** stores history (`wl-paste --watch cliphist store`, run by the island shell `qs -c island`); Mod+V → `dms ipc call clipboard toggle`. `clip-push.service` (`scripts/clip-push.sh`) is a second watcher that pushes copied images to novahome | `nova/.config/quickshell/island/shell.qml`, `nova/.config/niri/dms/binds.kdl` |

## Shell & Terminal

| Tool | Details |
|------|---------|
| **Shell** | zsh (primary, default login shell); fish config is kept but unused |
| **Terminal** | Ghostty (ZedMono Nerd Font, size 13, themed by `scripts/theme.sh`, 90% opacity) |
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
   - `pluginload.zsh` — zsh plugins (autopair, syntax-highlighting, deja inline suggestions); the fish-style Tab menu is native `menu select`, configured in `.zshrc`
   - `prompt.zsh` — powerline-style prompt with git/language detection
4. **fish** (unused, zsh is the login shell) — `~/.config/fish/config.fish` re-declares the same env/PATH, then auto-loads `conf.d/*.fish` (aliases, autopair, auto-venv). Completions: carapace bridge + native fish + man-page-generated (`fish_update_completions`). Plugins via fisher (`fish_plugins`). Inline autosuggestions read `~/.local/share/fish/fish_history` (not atuin's DB).

### Notable Aliases
- `rm` → `trash-put` (safe delete)
- `cp` → `rsync` (progress bar)
- `ls/la/ll/lt` → `eza` variants
- `gadd` → auto-stage and commit with message
- `winstart/winstop/winrestart/winsopen` → drive the Windows VM on `novahome` over ssh + docker

## Editors

### Neovim (only editor; Emacs removed 2026-10-07)
- `$EDITOR`/`$VISUAL`, `tv-edit.sh` (Mod+Shift+D), lazygit (`scripts/lazygit-edit.sh`, new tmux window) and Mod+N (`ghostty -e nvim`) all run plain `nvim`
- MIME defaults use `nvim.desktop` (overridden in `nova/.local/share/applications/`: the stock entry is `Terminal=true`, which glib cannot open under niri). PDFs go to zathura
- Config: `nova/.config/nvim/` (Lua-based)
- Plugin manager: lazy.nvim
- Leader key: Space
- Font: JetBrainsMonoNL Nerd Font, size 13
- Tabs: 4 spaces
- Layout: `init.lua`, `lua/config/keymaps.lua`, one spec per plugin in `lua/plugins/`, colours in `lua/theme.lua` (generated by `scripts/theme.sh`)

## Scripts (`scripts/`)

### System Control
| Script | Purpose |
|--------|---------|
| `brightness.sh` | Adaptive step brightness (1% below 32%, 5% above) |
| `volume.sh` | playerctl volume adjust |
| `battery-limit.sh` | Lenovo IdeaPad conservation mode (70%+ → enable). Lives in `system/system/usr/local/bin/`; the root timer runs the root-owned copy in `/usr/local/bin`, never the user-writable repo file |
| `dns.sh` | Toggle Adguard DNS on NetworkManager connection |
| `tv-only-output.sh` | Switch niri output to the TV only |

### Productivity
| Script | Purpose |
|--------|---------|
| `fix_grammar.sh` | Clipboard text → NVIDIA API (gpt-oss-120b) → grammar correction → paste back |
| `ocr_select.sh` | Region select → screenshot → RapidOCR (PP-OCRv6, `python-rapidocr` AUR) → clipboard |
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
- No charge thresholds in TLP (its ideapad driver only takes 0/1); `battery-limit.timer` toggles conservation mode
- WiFi power saving: off on AC, on on battery
- Sleep mode: s2idle (modern standby)

### Firewall (ufw)
- Incoming and routed: DROP by default; outgoing: ACCEPT
- Allow: SSH (22), KDE Connect (1714-1764 tcp/udp), 3000, 3001, mDNS/SSDP and 192.168.220.0/24 on wlan0
- Rules are recreated by `setup.sh`

### Boot
- systemd-boot (managed by `systemd-boot-manager`); no GRUB on this system
- Kernel params: `zswap.enabled=0 nowatchdog quiet splash` (btrfs root on subvol `@`)

### Systemd Services
- `battery-limit.timer` — runs `/usr/local/bin/battery-limit.sh` as root every 5 min
- `paccache.timer` — weekly; keeps 2 versions of installed packages, none of uninstalled (drop-in in `system/system/etc/systemd/system/paccache.service.d/`)
- Battery alerts come from the DMS `dankBatteryAlerts` plugin (batsignal was removed)

## Theming & Fonts

Colours are switchable across the whole desktop. `system/themes/palettes/<name>.env`
holds the only hand-written colours; `scripts/theme.sh <name>` renders every
themed config from `system/themes/templates/` with `envsubst`, and `Mod+Shift+T`
opens the Quickshell picker that drives the same script. Adding a theme means
adding one palette file. See `system/themes/README.md`.

- **Themes:** `catppuccin` (stock Mocha), `tokyonight` (Night), `rosepine`
  (main variant), `space-galaxy` (near-black base with Catppuccin accents and
  a nebula focus ring)
- **Never hand-edit a generated config** — every one carries a "generated by
  scripts/theme.sh" header. Edit the template or the palette instead.
- **GTK:** follows DankMaterialShell; both gtk.css files import `dank-colors.css`.
  The widget theme (`adw-gtk3-dark`) is fixed — only the colours change.
- **Qt:** left to DMS's own qt5ct/qt6ct templates and the xdg portal; not templated here
- **Terminal font:** ZedMono Nerd Font (size 13)
- **Editor font:** JetBrains Mono NL Nerd Font (size 13-15)
- **Icon theme:** Cool-Dark-Icons (Rofi), WhiteSur (GTK)

## Notifications

Notification popups come from `nova/.config/quickshell/notifications/`, ported by
hand from caelestia-shell. Popups only — there is no notification centre and no
history, so a dismissed notification is gone.

**Why it is a systemd unit and not a niri `spawn-at-startup`.** Only one process
can own `org.freedesktop.Notifications`, and DMS claims it unconditionally: its
`Services/NotificationService.qml` creates a `NotificationServer` with no setting
to disable it, and its QML ships inside the `dms` binary, extracted read-only to
`/run/user/1000/danklinux-shell/<hash>/`, so patching it does not survive. The
handover is arranged in systemd instead:

- `nova/.config/systemd/user/quickshell-notifications.service` starts
  `Before=dms.service` and does not report itself started until `ExecStartPost`
  sees the bus name is ours.
- `nova/.config/systemd/user/dms.service.d/override.conf` flips DMS from
  `Type=dbus` to `Type=simple`. Without it systemd waits ninety seconds for a bus
  name DMS can never get, fails the start, and restarts it on a loop.
- The unit sets `QML2_IMPORT_PATH` itself. niri's `environment {}` block only
  reaches processes niri spawns, so it does not cover systemd user services.

**What this costs.** DMS's notification centre on Mod+N still opens but is
permanently empty, its island notification badges never light up, and its
do-not-disturb controls do nothing. Everything else in DMS is unaffected.
Do-not-disturb is now `qs -c notifications ipc call notifs dnd`; `status` reports
it and `clear` dismisses whatever is on screen. Nothing is bound to those yet.

**Reverting.** Disable the unit, delete the drop-in, reload:

```sh
systemctl --user disable --now quickshell-notifications.service
rm -r ~/.dotfiles/nova/.config/systemd/user/dms.service.d
systemctl --user daemon-reload && systemctl --user restart dms.service
```

**Testing it.** `notify-send -a App -i google-chrome "Summary" "Body"`. Use an
icon name the theme actually has; a missing one falls back to a lettered badge,
which is deliberate.

## Browsers
- **Primary:** Zen Browser (Wayland)
- **Secondary:** Qutebrowser (keyboard-driven, dark mode, follows the active theme)
- **Work:** Google Chrome

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
- **MIME defaults** (`nova/.config/mimeapps.list`): zen (web), Neovim (Markdown, CSV/TSV, Org, plain text, logs, code, config), zathura (PDF, epub, PostScript), imv (images), mpv (video/audio). Without a desktop environment, `xdg-open` detects type by content (`file`), so small scripts can read as `text/plain` and open in Neovim; GTK apps detect by extension and are unaffected

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
| **Swap** | 7.6 GB zram (zstd, `ram / 2`) + 8 GB swap file (`/swap/swapfile`) |
| **WiFi** | Intel AX211 (WiFi 6E, CNVi, Meteor Lake PCH) |
| **Bluetooth** | Intel AX211 BT 5.3 |
| **Webcam** | Bison Integrated RGB Camera (USB) |
| **Card Reader** | O2 Micro SD/MMC Controller |
| **Ports** | Thunderbolt 4 (USB-C), USB 3.2 Gen 2x1 |
| **Display** | 14" 1920x1080 @ 60 Hz (eDP-1), intel_backlight |
| **Kernel** | linux-cachyos 7.2.x (PREEMPT_DYNAMIC, clang/LLD built) |
| **Filesystem** | Btrfs (single partition for / and /home) |
| **Networking** | Tailscale VPN active, Docker/Podman bridge networks |

### Hardware-Specific Config Notes
- **TLP** is tuned for Meteor Lake: s2idle sleep, Intel HWP, NatACPI enabled (charge limit handled by `battery-limit.timer`)
- **Battery conservation** managed via Lenovo IdeaPad ACPI sysfs (`/sys/bus/platform/drivers/ideapad_acpi/`)
- **i915 PSR** (Panel Self Refresh) enabled in kernel params for display power saving
- **intel-compute-runtime** + **intel-media-driver** installed for OpenCL and media acceleration
- NPU: kernel driver (`intel_vpu`) loaded; the userspace `intel-npu-driver` is not installed
- **No NVIDIA or gaming packages** — nvidia.yaml is fully commented out; gaming.yaml and Steam were removed 2026-09-26

## Important Notes

- **Wayland-native:** All scripts assume Wayland (wl-copy, slurp, grim, ydotool, niri msg)
- **Nerd Fonts required:** Icons used throughout rofi, quickshell, prompts, and terminal configs
- **Sensitive files:** API keys and credentials are stored in `.profile` and `.env` files — never commit actual values
