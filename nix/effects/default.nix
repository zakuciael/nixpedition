{ inputs, ... }:
{
  imports = [
    inputs.hercules-ci-effects.flakeModule
  ];

  flake-file.inputs.hercules-ci-effects = {
    url = "github:hercules-ci/hercules-ci-effects";
    inputs = {
      nixpkgs.follows = "nixpkgs";
      flake-parts.follows = "flake-parts";
    };
  };
}
