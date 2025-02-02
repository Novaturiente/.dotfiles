{ config, lib, pkgs, ... }:

{
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;

  environment.systemPackages = with pkgs; [
    vulkan-tools

    lutris

    wineWowPackages.stable
    wine
    wine64
    winetricks
    wineWowPackages.waylandFull

    gzip
    curl

    dwarfs
    fuse-overlayfs
  ];

  
  security.wrappers.fuse = {
    source = "${pkgs.fuse}/bin/fusermount";
    group = "users";
    owner = "nova";
    capabilities = "cap_sys_admin=eip";
  };
}

