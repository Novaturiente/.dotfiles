{ config, lib, pkgs,pkgs-unstable, ... }:

{
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

  environment.sessionVariables = rec {
    LIBVIRT_DEFAULT_URI="qemu:///system";
  };

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
    iproute2
    libnotify
    netcat-gnu
    libvirt-glib
    distrobox
    virtiofsd
  ];
  
  specialisation = {
    gaming.configuration = {
      system.nixos.tags = [ "gaming" ];
      boot.blacklistedKernelModules = [ "nouveau" "nvidia" ];
      boot.kernelParams = [ 
        "intel_iommu=on" # For Intel CPUs
        "iommu=pt"
      ];
      boot.kernelModules = [ "vfio" "vfio_iommu_type1" "vfio_pci" "vfio_virqfd" ];
      boot.extraModprobeConfig = ''
        options vfio-pci ids=10de:25a9
      '';
    };
  };
}

