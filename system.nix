{ inputs, config, lib, pkgs, modulesPath, pkgs-unstable, ... }:

{
  imports =
    [ 
      ./packages.nix
      ./nvidia.nix
      ./flatpak.nix
      ./virtualization.nix
#      ./extra.nix
    ];

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  services.xserver.enable = true;
  services.displayManager.ly.enable = true;
  services.desktopManager.plasma6.enable = true;

  networking.firewall = {
    enable = true;
    allowedUDPPortRanges = [
      { from = 1714; to = 1764; }
    ];
    allowedTCPPortRanges = [
      { from = 1714; to = 1764; }
    ];
    allowedTCPPorts = [5555];
    allowedUDPPorts = [ ];
  };

  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    plasma-browser-integration
    konsole
    kate
    elisa
    discover
    kmenuedit
    okular
    plasma-systemmonitor
    spectacle
  ];

  environment.systemPackages = with pkgs; [
    home-manager
    kdePackages.kdeconnect-kde
    kdePackages.dolphin
    catppuccin-cursors.mochaMauve
    waybar                   
    pamixer                  
    playerctl                
    clipman                  
    wl-clipboard           
    alsa-utils             
    brightnessctl          
    grim
    mako
    slurp
    swappy                 
    wlinhibit               
    hyprlock                
    xbindkeys               
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
    pkgs-unstable.rofi-wayland
    swayosd
    hyprpolkitagent
    sshfs
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
    (nerdfonts.override { fonts = [ "JetBrainsMono" "FiraCode" "SpaceMono" "AnonymousPro"]; })
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

  environment.sessionVariables = rec {
    LIBVIRT_DEFAULT_URI="qemu:///system";
  };

  environment.etc."fuse.conf".text = ''
    user_allow_other
  '';
}

