{ config, lib, pkgs,pkgs-unstable, ... }:

{
  
  services.xserver.desktopManager.gnome.enable = true;
  
  environment.systemPackages = with pkgs.gnomeExtensions; [
    dock-from-dash
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
  ];
}

