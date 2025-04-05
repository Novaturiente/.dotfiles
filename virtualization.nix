{ config, lib, pkgs, pkgs-unstable,... }:

{
  # QEMU/KVM and libvirt configuration
  programs.virt-manager.enable = true;
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      ovmf.enable = true; # UEFI support for VMs
    };
    onBoot = "ignore";
    onShutdown = "shutdown";
  };
  virtualisation.spiceUSBRedirection.enable = true;
  
  # Docker configuration
  virtualisation.docker = {
    enable = true;
    storageDriver = "btrfs"; # Use btrfs for better snapshot support
    package = pkgs-unstable.docker; # Use unstable version
    rootless = {
      enable = true;
      daemon.settings = {
        features.cdi = true;
        runtimes.nvidia.path = "${pkgs.nvidia-docker}/bin/nvidia-container-runtime";
      };
    };
  };
  
  # Podman (alternative container runtime)
  virtualisation.podman.enable = true;
}

