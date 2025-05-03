# Combined NixOS Configuration File
{ config, lib, pkgs, modulesPath, ... }:

let
  # Define unstable packages source
  pkgs-unstable = import <nixpkgs-unstable> {
    inherit system;
    config.allowUnfree = true;
  };
  system = "x86_64-linux";
in
{
  #######################
  # CORE SYSTEM CONFIGURATION
  #######################
  
  # Import hardware configuration
  imports = [ ./hardware-configuration.nix ];

  # Bootloader configuration
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
      systemd-boot.configurationLimit = 3; # Limit stored generations
    };
    kernelPackages = pkgs.linuxPackages_6_12; # Use specific kernel version
    
    # VFIO/PCI passthrough for gaming VM setup
    kernelModules = [ "kvm-intel" "vfio" "vfio_iommu_type1" "vfio_pci" "vfio_virqfd" ];
    extraModprobeConfig = ''
      options vfio-pci ids=10de:25a9 # NVIDIA GPU ID for passthrough
    '';
  };

  # Basic system identification
  networking = {
    hostName = "novarch"; # Define hostname
    networkmanager.enable = true; # Enable NetworkManager
    wireless.enable = false; # Disable wpa_supplicant
    
    # Firewall configuration
    firewall = {
      enable = true;
      allowPing = true;
      # KDE Connect ports
      allowedUDPPortRanges = [
        { from = 1714; to = 1764; }
        { from = 32768; to = 61000; } # High ports
      ];
      allowedTCPPortRanges = [
        { from = 1714; to = 1764; }
        { from = 8008; to = 8009; }
      ];
      allowedTCPPorts = [5555]; # ADB port
      allowedUDPPorts = [];
    };
  };

  # Locale and timezone settings
  time.timeZone = "Asia/Kolkata";
  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT = "en_US.UTF-8";
      LC_MONETARY = "en_US.UTF-8";
      LC_NAME = "en_US.UTF-8";
      LC_NUMERIC = "en_US.UTF-8";
      LC_PAPER = "en_US.UTF-8";
      LC_TELEPHONE = "en_US.UTF-8";
      LC_TIME = "en_US.UTF-8";
    };
  };

  # X11 keyboard configuration
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Audio configuration with PipeWire
  security.rtkit.enable = true; # Realtime scheduling for audio
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true; # PulseAudio compatibility
  };

  # User account configuration
  users.users.nova = {
    isNormalUser = true;
    description = "Nova";
    extraGroups = [ 
      "networkmanager" 
      "wheel"  # Admin privileges
      "docker" 
      "libvirtd" 
      "adbusers" 
      "kvm" 
      "qemu-libvirtd"
    ];
    shell = pkgs.fish;
    packages = with pkgs; [
      # User-specific packages go here
    ];
  };

  # Enable Fish shell
  programs.fish.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Experimental features for Nix
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  #######################
  # DESKTOP ENVIRONMENT CONFIGURATION
  #######################
  
  # Enable X11 and display manager
  services.xserver.enable = true;
  services.displayManager.ly.enable = true; # Minimal display manager
  
  # GNOME configuration
  services.xserver.desktopManager.gnome.enable = true;
  
  # Excluded GNOME packages to reduce bloat
  environment.gnome.excludePackages = with pkgs; [
    orca
    evince
    gnome-tour
    gnome-text-editor
    gnome-calculator
    gnome-calendar
    gnome-characters
    gnome-clocks
    gnome-console
    gnome-contacts
    gnome-font-viewer
    gnome-logs
    gnome-maps
    gnome-music
    gnome-system-monitor
    gnome-weather
    totem
    yelp
    gnome-software
  ];
  
  # Hyprland (Wayland compositor)
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    portalPackage = pkgs.xdg-desktop-portal-hyprland;
  };
  
  # XDG desktop integration
  xdg = {
    menus.enable = true;
    mime.enable = true;
    portal.enable = true;
  };
  
  # Theme configuration
  catppuccin.flavor = "mocha";
  catppuccin.enable = true;

  #######################
  # GRAPHICS CONFIGURATION
  #######################
  
  # NVIDIA drivers and configuration
  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
    };
    
    # NVIDIA-specific settings
    nvidia = {
      modesetting.enable = true;
      powerManagement.enable = true;
      powerManagement.finegrained = true;
      open = true;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.production;
      
      # NVIDIA Optimus (hybrid graphics) configuration
      prime = {
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
        nvidiaBusId = "PCI:1:0:0";
        intelBusId = "PCI:0:2:0";
      };
    };
  };
  
  # Enable NVIDIA container toolkit for Docker
  hardware.nvidia-container-toolkit.enable = true;

  #######################
  # VIRTUALIZATION
  #######################
  
  # QEMU/KVM and libvirt configuration
  programs.virt-manager.enable = true;
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      ovmf.enable = true; # UEFI support for VMs
    };
    onBoot = "ignore";
    onShutdown = "shutdown";
  };
  virtualisation.spiceUSBRedirection.enable = true;
  
  # Docker configuration
  virtualisation.docker = {
    enable = true;
    storageDriver = "btrfs"; # Use btrfs for better snapshot support
    package = pkgs-unstable.docker; # Use unstable version
    rootless = {
      enable = true;
      daemon.settings = {
        features.cdi = true;
        runtimes.nvidia.path = "${pkgs.nvidia-docker}/bin/nvidia-container-runtime";
      };
    };
  };
  
  # Podman (alternative container runtime)
  virtualisation.podman.enable = true;
  
  # Gaming specialization (creates an alternative boot option)
  specialisation = {
    gaming.configuration = {
      system.nixos.tags = [ "gaming" ];
      boot.blacklistedKernelModules = [ "nouveau" "nvidia" ];
      boot.kernelParams = [ 
        "intel_iommu=on" # For Intel CPUs
        "iommu=pt"
      ];
    };
  };

  #######################
  # FLATPAK CONFIGURATION
  #######################
  
  services.flatpak = {
    enable = true;
    package = pkgs-unstable.flatpak;
    
    # Add Flathub repository
    remotes = lib.mkOptionDefault [{
      name = "flathub";
      location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
    }];
    
    # Pre-installed Flatpak applications
    packages = [
      "app.zen_browser.zen"
      "org.qbittorrent.qBittorrent"
      "com.github.tchx84.Flatseal"
      "org.remmina.Remmina"
      "com.freerdp.FreeRDP"
      "net.mullvad.MullvadBrowser"
    ];
    
    # Global overrides for Flatpak applications
    overrides = {
      global = {
        # Force Wayland by default
        Context.sockets = ["wayland" "!x11" "!fallback-x11"];
        
        Environment = {
          GTK_THEME = "Catppuccin-Macchiato";
        };
      };
    };
  };

  #######################
  # SYNCTHING FILE SYNC
  #######################
  
  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
    user = "nova";
    configDir = "/home/nova/.conifg/syncthing";
    settings = {
      devices = {
        "Phone" = { id = "IWZA7TG-SL2QQV3-BIJ6A6B-N4CPSA5-AKEQG7Z-DWKYM3O-L7D6KIS-RO73FQF"; };
      };
      folders = {
        "Share" = {
          path = "/home/nova/Share";
          devices = [ "Phone" ];
        };
      };
    };
  };

  #######################
  # GAMING CONFIGURATION
  #######################
  
  programs.steam.gamescopeSession.enable = true;
  
  environment.variables = {
    PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION = "python";
    VK_ICD_FILENAMES = "/run/opengl-driver/share/vulkan/icd.d/intel_icd.x86_64.json:/run/opengl-driver-32/share/vulkan/icd.d/intel_icd.i686.json";
    NIXOS_OZONE_WL = "1"; # For Electron apps on Wayland
    LIBVIRT_DEFAULT_URI = "qemu:///system"; # Default libvirt connection
    XDG_MENU_PREFIX = "plasma-";
  };
  
  # FUSE configuration for special filesystems
  security.wrappers.fuse = {
    source = "${pkgs.fuse}/bin/fusermount";
    group = "users";
    owner = "nova";
    capabilities = "cap_sys_admin=eip";
  };
  
  environment.etc."fuse.conf".text = ''
    user_allow_other
  '';

  #######################
  # BLUETOOTH & HARDWARE
  #######################
  
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };

  #######################
  # SYSTEM PACKAGES
  #######################
  
  environment.systemPackages = with pkgs; [
    # Core system utilities
    wget
    duf                       # Disk usage/free utility
    rsync                     # File synchronization
    stow                      # Symlink manager for dotfiles
    gparted                   # Partition editor
    openssl                   # SSL/TLS toolkit
    lsof                      # Lists open files
    baobab                    # Disk usage analyzer
    yazi                      # File manager
    fastfetch                 # System info display
    gzip
    curl
    bat                       # Better cat
    unzip
    unrar
    p7zip
    htop                      # Process viewer
    nvtopPackages.full        # NVIDIA monitoring
    pciutils                  # PCI utilities
    usbutils                  # USB utilities
    killall                   # Process killer
    
    # Development tools
    cpio
    cmake
    gcc
    gnumake
    nmap
    file
    conda
    cargo
    rustc
    rust-analyzer
    rustfmt
    uv                        # Python package installer
    python310
    python312Packages.ollama  # Python bindings for Ollama
    nodejs
    lua
    lua51Packages.luarocks
    pyright                   # Python type checker
    
    # Browser
    pkgs-unstable.firefox
    geckodriver
    
    # Media
    vlc
    
    # Shell and terminal tools
    fishPlugins.done
    fishPlugins.fzf-fish
    fishPlugins.forgit
    fishPlugins.hydro
    fzf                       # Fuzzy finder
    fishPlugins.grc
    grc                       # Generic colourizer
    zoxide                    # Smarter cd command
    eza                       # Better ls
    ripgrep                   # Fast grep
    fd                        # Better find
    tree-sitter               # Parser for syntax highlighting
    
    # Virtualization and containers
    dialog
    iproute2
    libnotify
    netcat-gnu
    libvirt-glib
    distrobox                 # Container-based distros
    virtiofsd
    
    # Gaming related
    pkgs-unstable.lutris      # Game launcher
    wineWowPackages.staging   # Wine for Windows programs
    wineWowPackages.waylandFull
    protonup-qt               # Proton manager
    gamescope                 # SteamOS session compositing
    
    # NVIDIA and graphics tools
    linuxPackages.nvidia_x11
    cudaPackages.cudatoolkit
    cudaPackages.cudnn
    virtualgl
    vulkan-tools
    vpl-gpu-rt
    vulkan-loader
    vulkan-validation-layers
    vulkan-extension-layer
    intel-media-driver
    vaapiIntel
    vaapiVdpau
    libvdpau-va-gl
    intel-compute-runtime
    nvidia-vaapi-driver
    libva
    libva-utils
    glxinfo
    
    # Desktop environment tools
    ghostty                   # Terminal
    git
    pkgs-unstable.neovim
    ungoogled-chromium
    gnome-tweaks
    gnomeExtensions.dock-from-dash
    home-manager
    kdePackages.kdeconnect-kde
    kdePackages.dolphin
    catppuccin-cursors.mochaMauve
    
    # Wayland tools
    waybar                    # Status bar  
    playerctl                 # Media player control
    clipman                   # Clipboard manager
    wl-clipboard              # Command-line clipboard
    alsa-utils                # Audio utilities
    grim                      # Screenshot utility
    mako                      # Notification daemon
    slurp                     # Region selector
    swappy                    # Screenshot editor
    wlinhibit                 # Inhibits screen locking
    hyprlock                  # Screen locker
    waypaper                  # Wallpaper manager
    swww                      # Wallpaper daemon
    networkmanagerapplet      # Network manager UI
    gdk-pixbuf                # Image handling library
    rofi-wayland              # Application launcher
    swayosd                   # On-screen display
    hyprpolkitagent           # PolicyKit agent
    sshfs                     # SSH filesystem
    bluez-tools               # Bluetooth tools
    wireplumber               # Session/policy manager
    bluez                     # Bluetooth protocol stack
    blueman                   # Bluetooth manager
  ];
  
  # Install specific fonts
  fonts.packages = with pkgs; [
    (nerdfonts.override { 
      fonts = [ 
        "JetBrainsMono" 
        "FiraCode" 
        "SpaceMono" 
        "AnonymousPro" 
        "D2Coding"
      ]; 
    })
  ];

  # Set the system state version
  system.stateVersion = "24.11";
}
