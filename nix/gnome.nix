{ config, lib, pkgs,pkgs-unstable, ... }:

{

  services.xserver.desktopManager.gnome.enable = true;

  programs.dconf.enable = true;
 
  environment.systemPackages = with pkgs; [
    gnomeExtensions.dash-to-dock
    gnomeExtensions.blur-my-shell
    gnomeExtensions.caffeine
    gnomeExtensions.hide-top-bar
    gnomeExtensions.user-themes
    gnomeExtensions.clipboard-indicator
    gnomeExtensions.arcmenu
    gnomeExtensions.transparent-top-bar
    
    gnome-extension-manager
    gnome-tweaks
  ];

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
    geary
    epiphany
    snapshot
    simple-scan
    
    gnome-shell-extensions
#    gnomeExtensions.applications-menu
#    gnomeExtensions.launch-new-instance
#    gnomeExtensions.light-style
#    gnomeExtensions.native-window-placement
#    gnomeExtensions.places-status-indicator
#    gnomeExtensions.status-icons
#    gnomeExtensions.window-list
#    gnomeExtensions.windownavigator
#    gnomeExtensions.workspace-indicator
#    gnomeExtensions.removable-drive-menu
  ];
}

