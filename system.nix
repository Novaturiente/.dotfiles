{ config, lib, pkgs, modulesPath, ... }:

{
  services.xserver.enable = true; # optional
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
    kwallet
    kwalletmanager
    kmenuedit
    okular
    plasma-systemmonitor
    spectacle
  ];

  environment.systemPackages = with pkgs; [
    kdePackages.knewstuff
    kdePackages.kcmutils
    kdePackages.kcmutils
    kdePackages.kio
    kdePackages.kservice
    kdePackages.kdeconnect-kde
    kdePackages.xdg-desktop-portal-kde
    kdePackages.kcoreaddons
    kdePackages.kirigami
    polkit-kde-agent
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
    rofi                    
    wlinhibit               
    hyprlock                
    xbindkeys               
    killall
    waypaper                
    networkmanagerapplet
    gdk-pixbuf

    htop
    nvtopPackages.full
    bluetui
    bluez-tools
    wireplumber
    bluez
  ];

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };
 
  fonts.packages = with pkgs; [
 #   nerd-fonts.jetbrains-mono
 #   nerd-fonts.space-mono
 #   nerd-fonts.fira-code
    (nerdfonts.override { fonts = [ "JetBrainsMono" "FiraCode" "SpaceMono"]; })
  ];
  
  security = {
    polkit.enable = true;
    pam.services.kwallet = {
      name = "kwallet";
      enableKwallet = true;
    };
  };

  xdg.menus.enable = true;
  xdg.mime.enable = true;
  xdg.portal.enable = true;

  catppuccin.flavor = "mocha";
  catppuccin.enable = true;

  environment.variables = {
    XDG_MENU_PREFIX = "plasma-";
  };

}

