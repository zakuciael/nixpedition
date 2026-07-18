{ inputs, ... }:
let
  inherit (inputs.nixos-hardware.nixosModules) common-gpu-amd-sea-islands common-gpu-amd;
in
{
  hardware.amdgpu = {
    # Support for Sea Islands cards
    sea-islands.nixos.imports = [ common-gpu-amd-sea-islands ];

    nixos = {
      imports = [ common-gpu-amd ];

      # Use amdgpu instead of radeon
      services.xserver.videoDrivers = [ "amdgpu" ];
      boot.blacklistedKernelModules = [ "radeon" ];
      boot.extraModprobeConfig = ''
        blacklist radeon
        options radeon modeset=0
      '';
    };
  };
}
