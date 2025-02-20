{ config, lib, pkgs, ... }:

{
  
  environment.systemPackages = with pkgs; [
    mullvad-browser
    wget
    duf
    pyright
    rsync
    stow
    python3
    scrcpy
    gparted
    openssl
    lsof
    baobab
    yazi
    fastfetch
    gzip
    curl
    bat
    unzip
    unrar
    p7zip

    # Fish shell
    fishPlugins.done
    fishPlugins.fzf-fish
    fishPlugins.forgit
    fishPlugins.hydro
    fzf
    fishPlugins.grc
    grc
    zoxide
    eza

    # Gaming packages
    lutris
    gamescope
    wineWowPackages.stable
    winetricks
    wineWowPackages.waylandFull

    #Development
    cpio
    cmake
    gcc
    gnumake
  ];

  programs.adb.enable = true;

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "both";
  };

# Fish Terminal
  programs.fish.enable = true;
  
# Gaming setup
  security.wrappers.fuse = {
    source = "${pkgs.fuse}/bin/fusermount";
    group = "users";
    owner = "nova";
    capabilities = "cap_sys_admin=eip";
  };
}
