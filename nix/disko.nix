{
  lib,
  config,
  inputs,
  den,
  ...
}:
let
  rootConfig = config;
  diskoConfigurations = rootConfig.flake.diskoConfigurations;
in
{
  imports = [ inputs.disko.flakeModule ];

  flake-file.inputs = {
    disko.url = "github:nix-community/disko";
  };

  flake.diskoConfigurations = { };

  den.aspects.disko.provides.define-disks = den.lib.parametric.exactly {
    description = lib.literalMD ''
      Defines a disks configuration at the OS level using disko.

      ## Usage
      ```
      den.default.includes = [ den.aspects.disko.provides.define-disks ]
      ```
      or using the Angle-Brackets syntax
      ```
      den.default.includes = [ <disko/define-disks> ]
      ```
    '';

    includes = [
      (
        { OS, host }:
        den.lib.take.unused OS {
          nixos = {
            imports = [
              inputs.disko.nixosModules.default
            ];

            config = lib.warnIfNot (diskoConfigurations ? "${host.hostName}") ''
              The disko configuration for host "${host.hostName}" is not defined.
            '' (diskoConfigurations."${host.hostName}" or { });
          };
        }
      )
    ];
  };
}
