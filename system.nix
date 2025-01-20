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
    scrcpy                  
    wlinhibit               
    hyprlock                
    xbindkeys               
    killall
    swww                    
    waypaper                
    polkit                   
    hyprpolkitagent
    networkmanagerapplet
    gdk-pixbuf
    xdg-desktop-portal
    xdg-desktop-portal-hyprland
  ];

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };
 
  fonts.packages = with pkgs; [
    (nerdfonts.override { fonts = [ "JetBrainsMono" "FiraCode" "SpaceMono"]; })
  ];
  
  security.polkit.enable = true;

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
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

