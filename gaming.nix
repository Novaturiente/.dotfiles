{ config, lib, pkgs, ... }:

{
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;

  environment.systemPackages = with pkgs; [
    vulkan-tools

    wineWowPackages.staging 
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

