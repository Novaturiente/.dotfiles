{ config, lib, pkgs, pkgs-unstable,... }:
{
  # QEMU/KVM and libvirt configuration remains the same
  programs.virt-manager.enable = true;
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      ovmf.enable = true;
    };
    onBoot = "ignore";
    onShutdown = "shutdown";
  };
  virtualisation.spiceUSBRedirection.enable = true;
  
  # Simplified Docker configuration
  virtualisation.docker = {
    enable = true;
    storageDriver = "btrfs";
    package = pkgs.docker;
    rootless.enable = true;
    daemon.settings = {
      features.cdi = true;
    };
  };

  # Podman
  virtualisation.podman.enable = true;
}
