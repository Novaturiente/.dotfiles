{ inputs, config, lib, pkgs, modulesPath, pkgs-unstable, ... }:

{
  imports =
    [ 
      ./packages.nix
      ./nvidia.nix
      ./flatpak.nix
      ./virtualization.nix
      ./gaming.nix
      ./gnome.nix
#      ./fileserver.nix
    ];

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  services.xserver.enable = true;
  services.displayManager.ly.enable = true;
#  services.desktopManager.plasma6.enable = true;

  programs.ssh.askPassword = lib.mkForce "${pkgs.kdePackages.ksshaskpass.out}/bin/ksshaskpass";

  networking.firewall = {
    enable = true;
    allowPing = true;
    allowedUDPPortRanges = [
      { from = 1714; to = 1764; }
      { from = 32768; to = 61000; }
    ];
    allowedTCPPortRanges = [
      { from = 1714; to = 1764; }
      { from = 8008; to = 8009; }
    ];
    allowedTCPPorts = [5555];
    allowedUDPPorts = [];
  };

  environment.systemPackages = with pkgs; [
    home-manager
    kdePackages.kdeconnect-kde
#    kdePackages.dolphin
    catppuccin-cursors.mochaMauve
    waybar                   
    playerctl                
    clipman                  
    wl-clipboard           
    alsa-utils             
    grim
    mako
    slurp
    swappy                 
    wlinhibit               
    hyprlock                
    killall
    waypaper
    swww
    networkmanagerapplet
    gdk-pixbuf

    htop
    nvtopPackages.full
    bluez-tools
    wireplumber
    bluez
    blueman
    pciutils
    usbutils
    rofi-wayland
    swayosd
    hyprpolkitagent
    sshfs

    ripgrep
    fd
    tree-sitter
    nodejs
    lua
    lua51Packages.luarocks

    gnome-tweaks
  ];

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    portalPackage = pkgs.xdg-desktop-portal-hyprland;
  };

  security.polkit.enable = true;

  fonts.packages = with pkgs; [
  #  nerd-fonts.jetbrains-mono
  #  nerd-fonts.space-mono
  #  nerd-fonts.fira-code
    (nerdfonts.override { fonts = [ "JetBrainsMono" "FiraCode" "SpaceMono" "AnonymousPro" "D2Coding"]; })
  ];

  xdg.menus.enable = true;
  xdg.mime.enable = true;
  xdg.portal.enable = true;

  catppuccin.flavor = "mocha";
  catppuccin.enable = true;
  
  environment.variables = {
    XDG_MENU_PREFIX = "plasma-";
  };

  #services.xserver.excludePackages = [ pkgs.xterm ];

  environment.etc."fuse.conf".text = ''
    user_allow_other
  '';

#  environment.plasma6.excludePackages = with pkgs.kdePackages; [
#    plasma-browser-integration
#    konsole
#    kate
#    elisa
#    discover
#    kmenuedit
#    okular
#    plasma-systemmonitor
#    spectacle
#    plasma-systemmonitor
#  ];
}

