{ config, lib, pkgs, pkgs-unstable,... }:

{
   environment.systemPackages = with pkgs-unstable; [
    # Gaming packages
    lutris
    gamescope
    wineWowPackages.stable
    winetricks
    wineWowPackages.waylandFull
    bottles
  ];

}

