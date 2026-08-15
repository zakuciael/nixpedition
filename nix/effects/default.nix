{ inputs, ... }:
{
  imports = [
    inputs.nixbot-effects.flakeModule
  ];

  flake-file.inputs.nixbot-effects = {
    url = "github:zakuciael/nixbot-effects";
    inputs = {
      nixpkgs.follows = "nixpkgs";
      flake-parts.follows = "flake-parts";
      clan-core.follows = "clan-core";
    };
  };
}
