{ config, lib, pkgs, ... }:

{
  # Enable OpenGL
  services = {
    xserver = {
      enable = true;
      videoDrivers = [ "nvidia" ];
    };
  };

  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        vpl-gpu-rt
        vulkan-loader
        vulkan-tools
        vulkan-validation-layers
      ];
    };
    
    # Load Nvidia driver for Xorg and Wayland
    nvidia = {
      modesetting.enable = true;
      powerManagement.enable = true;
      powerManagement.finegrained = true;
      open = false;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;

      prime = {
        #sync.enable = true;
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
        nvidiaBusId = "PCI:1:0:0";
        intelBusId = "PCI:0:2:0";
      };
    };
  };

  environment.systemPackages = with pkgs; [
    linuxPackages.nvidia_x11
    cudaPackages.cudatoolkit
    cudaPackages.cudnn
    virtualgl
  ];

  hardware.nvidia-container-toolkit.enable = true;

  virtualisation.docker.daemon.settings.features.cdi = true;
  virtualisation.docker.rootless.daemon.settings.features.cdi = true;
}

