{ inputs, ... }:
{
  hardware.amdgpu = {
    # Support for Sea Islands cards
    provides.sea-islands.nixos = {
      imports = with inputs.nixos-hardware.nixosModules; [
        common-gpu-amd-sea-islands
      ];
    };

    nixos = {
      imports = with inputs.nixos-hardware.nixosModules; [
        common-gpu-amd
      ];

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
