{ config, lib, pkgs, ... }:

{
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;

  environment.systemPackages = with pkgs; [
    steam-run
    dwarfs 
    vulkan-tools

    wineWowPackages.staging 
    winetricks
    wineWowPackages.waylandFull

    fuse-overlayfs
    dwarfs
    gzip
    curl
  ];

  
  security.wrappers.fuse = {
    source = "${pkgs.fuse}/bin/fusermount";
    group = "users";
    owner = "nova";
    capabilities = "cap_sys_admin=eip";
  };
}

