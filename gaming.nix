{ config, lib, pkgs, pkgs-unstable,... }:

{
   environment.systemPackages = with pkgs; [
    # Gaming packages
    lutris
    wineWowPackages.staging
    winetricks
    wineWowPackages.waylandFull

#    (python3.withPackages (ps: with ps; [
#      protobuf3_20  # Specifically use this version
#    ]))
  ];

  programs.steam.gamescopeSession.enable = true;

  environment.variables = {
    PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION = "python";
    VK_ICD_FILENAMES = "/run/opengl-driver/share/vulkan/icd.d/intel_icd.x86_64.json:/run/opengl-driver-32/share/vulkan/icd.d/intel_icd.i686.json";
    NIXOS_OZONE_WL = "1";
  };
}

