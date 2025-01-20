{ config, lib, pkgs, ... }:

{
  programs.virt-manager.enable = true;
  users.groups.libvirtd.members = ["nova"];
  virtualisation.libvirtd.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;

  users.users.nova.extraGroups = [ "libvirtd" ];
}

