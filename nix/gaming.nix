{ config, lib, pkgs, pkgs-unstable,... }:

{
   environment.systemPackages = with pkgs; [
    # Gaming packages
    pkgs-unstable.lutris
    wineWowPackages.staging
    wineWowPackages.waylandFull
    protonup-qt
    gamescope
  ];

  environment.variables = {
    PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION = "python";
    VK_ICD_FILENAMES = "/run/opengl-driver/share/vulkan/icd.d/intel_icd.x86_64.json:/run/opengl-driver-32/share/vulkan/icd.d/intel_icd.i686.json";
    NIXOS_OZONE_WL = "1";
  };
}

