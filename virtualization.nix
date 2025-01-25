{ config, lib, pkgs, ... }:

{
  programs.virt-manager.enable = true;
  users.groups.libvirtd.members = ["nova"];
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
    };
  };
  virtualisation.spiceUSBRedirection.enable = true;

  users.users.nova.extraGroups = [ "libvirtd" ];

  environment.systemPackages = with pkgs; [
    libvirt-glib
  ];

}

