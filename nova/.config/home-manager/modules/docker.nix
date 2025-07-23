
{ config, lib, pkgs, ... }:

{
  environment.systemPackages = [
    pkgs.docker
  ];

  systemd.services = {
    docker = {
      enable = true;
      description = "Docker Daemon";
      serviceConfig = {
        ExecStart = "${pkgs.docker}/bin/dockerd";
        Restart = "always";
        WantedBy = [ "multi-user.target" ];
      };
    };
  };
}
