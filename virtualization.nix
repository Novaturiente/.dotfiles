{ config, lib, pkgs,pkgs-unstable, ... }:

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
    storageDriver = "btrfs";
    package = pkgs-unstable.docker;
    rootless = {
      enable = true;
      daemon.settings = {
        features.cdi = true;
        runtimes.nvidia.path = "${pkgs.nvidia-docker}/bin/nvidia-container-runtime";
      };
    };
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
    distrobox
  ];
}

