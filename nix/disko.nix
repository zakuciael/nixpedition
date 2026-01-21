{
  lib,
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
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  flake.diskoConfigurations = { };
}
