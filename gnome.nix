{ config, lib, pkgs,pkgs-unstable, ... }:

{

  services.xserver.desktopManager.gnome.enable = true;

  programs.dconf.enable = true;
 
  environment.systemPackages = with pkgs; [
    gnomeExtensions.dock-from-dash
    gnomeExtensions.blur-my-shell
    gnomeExtensions.caffeine
    gnomeExtensions.pop-shell
    gnomeExtensions.appindicator
    gnomeExtensions.network-speed-monitor
    
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
  ];
}

