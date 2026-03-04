{
  lib,
  inputs,
  flake-parts-lib,
  ...
}:
let
  inherit (lib) mkOption types;
  inherit (flake-parts-lib) mkPerSystemOption;
in
{
  options = {
    perSystem = mkPerSystemOption {
      options.clan = {
        devShell = mkOption {
          type = types.package;
          readOnly = true;
        };
        devShellPackages = mkOption {
          type = types.listOf types.package;
          default = [ ];
        };
      };
    };
  };

  imports = [
    inputs.clan-core.flakeModules.default
  ];

  config = {
    flake-file.inputs = {
      clan-core = {
        url = "github:zakuciael/clan-core";
        inputs.nixpkgs.follows = "nixpkgs";
        inputs.flake-parts.follows = "flake-parts";
      };
    };

    flake.clan = {
      meta.name = "nixpedition";
      meta.domain = "nixpedition";
    };

    perSystem =
      {
        config,
        pkgs,
        inputs',
        ...
      }:
      {
        clan = {
          devShellPackages = [ inputs'.clan-core.packages.clan-cli ];
          devShell = pkgs.mkShell {
            packages = config.clan.devShellPackages;
          };
        };
      };
  };
}
