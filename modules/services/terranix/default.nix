{
  lib,
  inputs,
  moduleLocation,
  ...
}:
let
  inherit (lib)
    mapAttrs
    mkOption
    types
    ;
in
{
  imports = [ inputs.terranix.flakeModule ];

  options = {
    flake.terranixModules = mkOption {
      type = types.lazyAttrsOf types.deferredModule;
      default = { };
      apply = mapAttrs (
        k: v: {
          _class = "terranix";
          _file = "${toString moduleLocation}#terranixModules.${k}";
          imports = [ v ];
        }
      );
    };
  };

  config = {
    flake-file.inputs = {
      terranix = {
        url = "github:terranix/terranix";
        inputs = {
          nixpkgs.follows = "nixpkgs";
          flake-parts.follows = "flake-parts";
          systems.follows = "systems";
        };
      };
    };
  };
}
