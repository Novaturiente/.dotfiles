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

# Docker
  virtualisation.docker = {
    enable = true;
  };
  
  hardware.nvidia-container-toolkit.enable = true;

  virtualisation.docker.storageDriver = "btrfs";

  virtualisation.docker.rootless = {
    enable = true;
    setSocketVariable = true;
  };
  
  virtualisation.podman = {
    enable = true;
  };

  environment.systemPackages = with pkgs; [
    dialog
    freerdp3
    iproute2
    libnotify
    netcat-gnu
    libvirt-glib
  ];
}

