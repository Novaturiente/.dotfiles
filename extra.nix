{ config, lib, pkgs, pkgs-unstable,... }:

{
   environment.systemPackages = with pkgs-unstable; [
    # Gaming packages
    gamescope
    wineWowPackages.stable
    winetricks
    wineWowPackages.waylandFull
  ];

}

