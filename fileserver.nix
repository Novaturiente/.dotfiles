{ config, lib, pkgs, ... }:

{
  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
    user = "nova";
    configDir = "/home/nova/.conifg/syncthing";
    settings = {
      devices = {
        "Phone" = { id = "IWZA7TG-SL2QQV3-BIJ6A6B-N4CPSA5-AKEQG7Z-DWKYM3O-L7D6KIS-RO73FQF"; };
      };
      folders = {
        "Share" = {
          path = "/home/nova/Share";
          devices = [ "Phone" ];
        };
      };
    };
  };
}
