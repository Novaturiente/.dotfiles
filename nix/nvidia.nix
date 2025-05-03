{ config, lib, pkgs, pkgs-unstable, ... }:

{
  # Enable OpenGL
  services.xserver = {
      enable = true;
      videoDrivers = [ "nvidia" ];
  };

  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
    };
    
    # Load Nvidia driver for Xorg and Wayland
    nvidia = {
      modesetting.enable = true;
      powerManagement.enable = true;
      powerManagement.finegrained = true;
      open = true;
      nvidiaSettings = true;
      package = config.boot.kernelPackages.nvidiaPackages.latest;
#      package = pkgs-unstable.linuxPackages_6_14.nvidiaPackages.beta;
      

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
    vulkan-tools
    vpl-gpu-rt
    vulkan-loader
    vulkan-validation-layers
    vulkan-extension-layer
    intel-media-driver
    vaapiIntel
    vaapiVdpau
    libvdpau-va-gl
    intel-media-driver
    intel-compute-runtime
    nvidia-vaapi-driver
    libva
    libva-utils
    glxinfo
    nvidia-docker
  ];

  hardware.nvidia-container-toolkit.enable = true;

  virtualisation.docker.daemon.settings.features.cdi = true;
  virtualisation.docker.rootless.daemon.settings.features.cdi = true;

}

