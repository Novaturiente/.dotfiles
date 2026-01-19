# Arch Linux Dotfiles

Complete configuration repository for Arch Linux system setup, managed with GNU Stow for clean symlink-based dotfile management.

## 📁 Repository Structure

```
.dotfiles/
├── nova/              # Home directory configurations (stow-managed)
│   └── .config/       # Application configurations
├── scripts/           # Helper scripts and utilities
│   └── rofi/         # Rofi integration scripts
├── system/            # System-level configurations
│   ├── package/      # Package management YAML files
│   ├── system/etc/   # System configuration files
│   ├── setup.sh      # Initial system setup script
│   └── novarch       # Custom package manager script
└── podman/           # Podman container configurations
```

.dotfiles/nova/ is the home directory configurations (stow-managed), when editing configuration instead of looking at ~/.config first look at .dotfiles/nova/.config/

## 🚀 Quick Start

### Initial Setup

1. Clone the repository:
   ```bash
   git clone <repository-url> ~/.dotfiles
   cd ~/.dotfiles
   ```

2. Run the setup script (requires sudo):
   ```bash
   ./system/setup.sh
   ```

   **Warning:** The setup script will:
   - Install system packages
   - Copy system configurations to `/etc`
   - Configure firewall rules
   - Reboot the system automatically

### Stow Management

Home directory configurations are managed with GNU Stow:

```bash
# Create symlinks
stow -d ~/.dotfiles -t ~ nova

# Remove symlinks
stow -d ~/.dotfiles -t ~ -D nova
```

## 📦 Package Management

Packages are organized into YAML files in `system/package/`:

- **base-system.yaml** - Core system packages, drivers, utilities
- **nvidia.yaml** - NVIDIA graphics drivers and utilities
- **windowmanager.yaml** - Wayland compositor, desktop environment
- **development.yaml** - Development tools, language runtimes, linters
- **terminal-tools.yaml** - Terminal emulators, CLI utilities
- **media.yaml** - Media players, screen recording, image tools
- **internet.yaml** - Browsers, messaging, connectivity tools
- **work.yaml** - Work-specific applications, databases, IDEs
- **gaming.yaml** - Gaming libraries (currently commented)
- **virtualization.yaml** - Container/virtualization tools (currently commented)
- **manual-install.yaml** - Packages requiring manual installation

### Using novarch

The custom `novarch` script manages package installation from YAML files:

```bash
novarch init          # Initialize package management
novarch install <file> # Install packages from a YAML file
```

## 🛠️ Scripts

Helper scripts are located in `scripts/`:

### System Control
- `brightness.sh` - Adjust display brightness (adaptive steps)
- `volume.sh` - Control media player volume
- `mute.sh` - Toggle audio mute
- `idle.sh` - Toggle swayidle (screen lock/suspend)
- `dns.sh` - Configure DNS settings (AdGuard DNS)

### Utilities
- `wallpaper.sh` - Random wallpaper rotation (30min intervals)
- `llm.sh` - Ollama process management
- `windows.sh` - WinApps Podman container management
- `torrent.sh` - Deluge torrent client launcher
- `record-script.sh` - Screen recording with wf-recorder
- `start_tmux.sh` - Tmux session manager

### Rofi Integration (`scripts/rofi/`)
- `power.sh` - System power menu (logout/shutdown/reboot)
- `tmux.sh` - Tmux session launcher
- `clipboard.sh` - Clipboard history with image support
- `bookmarks.sh` - Browser bookmark management
- `tools.sh` - File operations (copy/move/rename/delete)
- `find.sh` - File search utility

## ⚙️ System Configuration

System-level configurations in `system/system/etc/`:

- **greetd/** - Display manager (tuigreet → niri)
- **ly/** - Alternative login manager configuration
- **tlp.conf** - Power management (RTX 2050 + Intel i5 12th Gen optimized)
- **systemd/sleep.conf** - Suspend/hibernate configuration
- **modprobe.d/** - NVIDIA sleep configuration
- **modules-load/** - Kernel modules (ntsync for WSL compatibility)
- **boot/grub/** - Custom GRUB theme (CyberSynchro)

## 🐳 Podman Containers

Container configurations in `podman/`:

- **ollama.yml** - Ollama LLM service (NVIDIA GPU support)
- **ollama-ui.yml** - Ollama web UI
- **immich/** - Immich photo management (GPU-accelerated ML)
- **macos.yaml** - macOS development container

## 🎨 Desktop Environment

- **Window Manager:** Niri (Wayland compositor)
- **Lockscreen:** ly
- **Top Bar:** Dank Linux
- **Terminal:** Ghostty
- **Shell:** ZSH
- **File Manager:** Yazi
- **Editor:** Doom Emacs + Neovim
- **Launcher:** Rofi

### 🌐 Qutebrowser Profiles

This configuration relies on two distinct browser profiles to balance privacy and usability:

- **Normal Profile:** Optimized for privacy and security. Uses stricter blocking lists and hardening settings.
- **Work Profile:** Configured for maximum compatibility. Permissive settings for Google services, Zoom, and other work tools.

## 🔧 Hardware Profile

- **Laptop:** Acer
- **CPU:** Intel i5 12th Gen
- **GPU:** NVIDIA RTX 2050
- **Power Management:** TLP with Acer-specific battery limiting

## 📝 Notes

- All scripts use `#!/usr/bin/env bash` for portability
- Configuration files are organized by application
- Backup files are ignored via `.gitignore`
- System setup requires root privileges

## 🔒 Security

The setup script configures iptables firewall with:
- Default INPUT policy: DROP
- Allows established/related connections
- Opens ports for KDE Connect (1714-1764)
- Opens SSH port (22)

## 📚 Additional Resources

- [GNU Stow Documentation](https://www.gnu.org/software/stow/)
- [Arch Linux Wiki](https://wiki.archlinux.org/)
- [Niri Documentation](https://github.com/YaLTeR/niri)

## 🆘 Disaster Recovery

Steps to restore the system from a fresh install or data loss:

### 1. Bootstrap Network (Live USB)
If running from a live environment without `setup.sh` network configs:
```bash
# Connect to WiFi manually if needed
iwctl station wlan0 connect <SSID>
```

### 2. Restore Secrets (Manual)
**CRITICAL:** These files are NOT in the repository and must be restored from an external encrypted backup (USB/Cloud).

*   **GPG Keys:** (Required for `pass` password manager)
    ```bash
    gpg --import private-key.asc
    gpg --import-ownertrust ownertrust.txt
    ```
*   **SSH Keys:**
    ```bash
    mkdir -p ~/.ssh
    cp /backup/id_ed25519 ~/.ssh/
    chmod 600 ~/.ssh/id_ed25519
    ```
*   **Rclone Config:** `~/.config/rclone/rclone.conf`

### 3. Clone & Provision
Once keys are restored (for git auth):
```bash
git clone git@github.com:username/dotfiles.git ~/.dotfiles
./system/setup.sh
```
