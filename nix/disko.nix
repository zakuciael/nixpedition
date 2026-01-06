{
  config,
  inputs,
  den,
  ...
}:
let
  rootConfig = config;
in
{
  imports = [ inputs.disko.flakeModule ];

  flake-file.inputs = {
    disko.url = "github:nix-community/disko";
  };

  flake.diskoConfigurations = { };

  den.provides.define-disks = den.lib.parametric.exactly {
    description = ''
      Defines a disks configuration at the OS level using disko.

      ## Usage
        den.default.includes = [ den._.define-disks ]
    '';

    includes = [
      (
        { OS, host }:
        den.lib.take.unused OS {
          nixos = {
            imports = [
              inputs.disko.nixosModules.default
            ];

            config = rootConfig.flake.diskoConfigurations."${host.hostName}";
          };
        }
      )
    ];
  };
}
