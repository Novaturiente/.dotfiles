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
    package = config.boot.kernelPackages.nvidiaPackages.beta;
  };

  hardware.nvidia.prime = {
    sync.enable = true;
#    offload = {
#      enable = true;
#      enableOffloadCmd = true;
#    };
    nvidiaBusId = "PCI:1:0:0";
    intelBusId = "PCI:0:2:0";
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

#  environment.variables = {
#    XDG_DATA_DIRS = lib.mkForce "/run/opengl-driver/share:$XDG_DATA_DIRS";
#    VK_ICD_FILENAMES="/run/opengl-driver/share/vulkan/icd.d/intel_icd.x86_64.json";
#  };
}

