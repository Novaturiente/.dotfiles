{ config, lib, pkgs, ... }:

{
  
  virtualisation.docker.enable = true;

  virtualisation.docker.storageDriver = "btrfs";

  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true;
  };

  environment.systemPackages = with pkgs; [
    dialog
    freerdp3
    iproute2
    libnotify
    netcat-gnu
  ];

}

