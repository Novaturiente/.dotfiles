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
    vlc

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

    #Development
    cpio
    cmake
    gcc
    gnumake
    nmap
    file
    
    #Gaming
    bottles
    lutris
    gamescope
    wineWowPackages.stable
    winetricks
    wineWowPackages.waylandFull
    bottles

    brave
  ];

  programs.adb.enable = true;

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "both";
  };

# Fish Terminal
  programs.fish.enable = true;

  programs.gamescope = {
    enable = true;
  };
  
# Gaming setup
  security.wrappers.fuse = {
    source = "${pkgs.fuse}/bin/fusermount";
    group = "users";
    owner = "nova";
    capabilities = "cap_sys_admin=eip";
  };
}
