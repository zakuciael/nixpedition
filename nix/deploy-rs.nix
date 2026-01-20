{
  config,
  lib,
  inputs,
  flake-parts-lib,
  ...
}:
let
  inherit (lib) mapAttrs mkOption types;
  inherit (flake-parts-lib) mkSubmoduleOptions;
in
{
  options = {
    flake.deploy = mkSubmoduleOptions {
      nodes = mkOption {
        type = types.lazyAttrsOf types.attrs;
      };
    };
  };

  config = {
    flake-file.inputs = {
      deploy-rs = {
        # TODO: Remove rev when merged to upstream
        url = "github:serokell/deploy-rs?rev=7edf1f4fd866fc5718aa5358dc720f4ee90909e3";
        inputs = {
          flake-compat.follows = "flake-compat";
          utils.follows = "dedupe-flake-utils";
          nixpkgs.follows = "nixpkgs";
        };
      };
    };

    flake.deploy.nodes =
      config.flake.nixosConfigurations
      |> mapAttrs (
        hostname: host:
        let
          inherit (host.pkgs.stdenv.hostPlatform) system;
        in
        {
          inherit hostname;
          profiles.system = {
            user = "root";
            interactiveSudo = true;
            autoRollback = true;
            magicRollback = true;
            path = inputs.deploy-rs.lib.${system}.activate.nixos host;
          }
          // (lib.optionalAttrs (host.config.security.doas.enable or false) {
            sudo = "doas -u";
          });
        }
      );

    perSystem =
      { system, ... }:
      {
        checks = inputs.deploy-rs.lib.${system}.deployChecks config.flake.deploy;
      };
  };
}
