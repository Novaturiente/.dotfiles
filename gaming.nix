{ config, lib, pkgs, pkgs-unstable,... }:

{
   environment.systemPackages = with pkgs; [
    # Gaming packages
    lutris
    wineWowPackages.staging
    winetricks
    wineWowPackages.waylandFull
  ];

}

