
{ config, lib, pkgs, ... }:

{
  nixpkgs.hostPlatform = "x86_64-linux";
  system-manager.allowAnyDistro = true;

  environment.systemPackages = [
    pkgs.tailscale
  ];

  systemd.services = {
    tailscaled = {
      enable = true;
      description = "Tailscale Daemon";
      serviceConfig = {
        ExecStart = "${pkgs.tailscale}/bin/tailscaled";
        Restart = "on-failure";
      };
      wantedBy = [ "multi-user.target" ];
    };
  };
}



