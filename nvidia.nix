{ config, lib, pkgs, ... }:

{
  # Enable OpenGL
  services.xserver.videoDrivers = ["nvidia" ];
  
  hardware.graphics = {
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

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  hardware.nvidia.prime = {
#    sync.enable = true;
    offload = {
      enable = true;
      enableOffloadCmd = true;
    };
    intelBusId = "PCI:0:2:0";
    nvidiaBusId = "PCI:1:0:0";
  };

  environment.systemPackages = with pkgs; [
    linuxPackages.nvidia_x11
    cudaPackages.cudatoolkit
    cudaPackages.cudnn
  ];

  hardware.nvidia-container-toolkit.enable = true;

  environment.variables = {
    XDG_DATA_DIRS = lib.mkForce "/run/opengl-driver/share:$XDG_DATA_DIRS";
  };
}

